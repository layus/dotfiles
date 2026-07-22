#!/usr/bin/env python3

import sys
# Run under systemd with stdout piped to the journal: without this, prints are
# block-buffered and can be lost entirely if the process is later killed
# (e.g. by session teardown) before the buffer flushes.
sys.stdout.reconfigure(line_buffering=True)

# For GTK4 Layer Shell to get linked before libwayland-client we must explicitly load it before importing with gi
from ctypes import CDLL
CDLL('libgtk4-layer-shell.so')

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4SessionLock', '1.0')

from gi.repository import Gtk
from gi.repository import Gdk
from gi.repository import GLib
from gi.repository import Gtk4SessionLock as SessionLock

import os
import time
from datetime import date, datetime
from pathlib import Path

# Exit codes the service unit keys off: EXIT_TEMPFAIL asks it to start us again
# after RestartSec (via Restart=on-failure + RestartForceExitStatus=75), while
# EXIT_DONE ends the retry loop for good. Exiting 75 does leave the unit
# momentarily "failed" in the journal, which is deliberate: marking it a success
# would stop on-failure from ever restarting us.
EXIT_DONE = 0
EXIT_TEMPFAIL = 75  # EX_TEMPFAIL

# When the session lock cannot be acquired (e.g. the screen is already locked by
# another locker), retry acquiring it on a fixed interval instead of giving up.
RETRY_INTERVAL_SECONDS = 10 * 60           # every 10 minutes
#
# 23h, and it must stay under the 24h between timer firings. That is what keeps
# one day's attempt from ever meeting the next day's: an attempt started at
# 15:30 expires at 14:30, an hour before the timer fires again, so the retry
# chain has always exited and cleared its state file by then. Raise this to 24h
# or more and a still-running chain would be handed the next day's activation,
# with no way to tell that apart from one of its own restarts.
RETRY_MAX_DURATION_SECONDS = 23 * 60 * 60

# The retry loop spans several processes (see restart_for_retry), so the two
# facts that must outlive any one of them are kept in a small state file:
#
#   * the day the entry belongs to, so a prompt that is only answered on a later
#     day is still filed under the day it was launched for, and
#   * the instant the retrying stops, so restarts cannot extend the 23h budget.
#
# It lives in XDG_RUNTIME_DIR, which is tmpfs cleared when the session ends --
# the same lifetime the deadline is meant to have, so a logout cannot leave one
# day's budget lying around for the next. Within a session, check_still_wanted()
# is what keeps a carried-over attempt from outliving its day.
STATE_PATH = Path(
    os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
) / "timesheets-prompt.state"


def fresh_state():
    return date.today(), time.time() + RETRY_MAX_DURATION_SECONDS


def load_state():
    """Read (start date, deadline) carried over from a previous attempt.

    Anything unusable -- absent file, torn write, garbage, or a deadline that
    cannot belong to a live attempt -- is treated as "no previous attempt" and
    starts a fresh budget. Sanity-checking the deadline matters as much as
    parsing it: a write truncated mid-float reads back as a 1970 timestamp,
    which would look like an expired budget and silently skip the day.
    """
    try:
        raw_date, raw_deadline = STATE_PATH.read_text().split()
        start_date = date.fromisoformat(raw_date)
        deadline = float(raw_deadline)
    except (OSError, ValueError):
        return fresh_state()

    # Reject a deadline no real attempt could have written -- too far ahead, or
    # so far behind that it cannot be this session's (a float truncated by a
    # torn write reads back as a 1970 timestamp). An expired-but-plausible one
    # is kept deliberately: that is exactly what check_still_wanted() needs to
    # see in order to stop, and replacing it here would hand out a fresh budget.
    age = time.time() - deadline
    if not -RETRY_MAX_DURATION_SECONDS <= age <= RETRY_MAX_DURATION_SECONDS:
        return fresh_state()
    return start_date, deadline


START_DATE, RETRY_DEADLINE = load_state()


def save_state():
    """Persist the day and deadline for the process that replaces us.

    Written atomically: a torn write would be read back as a bogus deadline by
    the very next process, and the whole point of the file is that the next
    process can trust it.
    """
    tmp = STATE_PATH.with_suffix(".tmp")
    try:
        tmp.write_text(f"{START_DATE.isoformat()} {RETRY_DEADLINE!r}\n")
        os.replace(tmp, STATE_PATH)
        return True
    except OSError as err:
        print(f"Could not save state to {STATE_PATH}: {err}")
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass
        return False


def clear_state():
    """Drop the state file once the retry loop is over, successfully or not."""
    try:
        STATE_PATH.unlink(missing_ok=True)
    except OSError:
        pass


def exit_now(code):
    """Leave the process immediately with `code`.

    Every caller runs inside a GLib callback, where PyGObject swallows a raised
    SystemExit and merely logs a traceback -- leaving the process alive and held
    with nothing scheduled, which is the very hang this all exists to prevent.
    """
    if code == EXIT_TEMPFAIL:
        # Only ask for a restart if the deadline can actually be handed on. If
        # it cannot, every later attempt would mint a fresh 23h budget and the
        # retrying would never end, so stop here instead.
        if not save_state():
            print("Cannot carry the deadline forward; giving up instead.")
            code = EXIT_DONE
    if code != EXIT_TEMPFAIL:
        clear_state()
    sys.stdout.flush()
    os._exit(code)


# gtk4-layer-shell's `monitor` signal can fire before (or without) a matching
# `locked` signal -- e.g. right after resuming from sleep, when the compositor
# is slow to respond to the lock request. Calling assign_window_to_monitor()
# before the lock is confirmed logs "no current lock in place" and silently
# produces no visible surface, leaving an invisible process running forever.
# If neither `locked` nor `failed` shows up within this window, give up on this
# *process* (see restart_for_retry) rather than on the lock attempt alone.
LOCK_CONFIRM_TIMEOUT_SECONDS = 30


def restart_for_retry(reason):
    """Exit and ask systemd to start us again later.

    A lock request the compositor never answers cannot be retried in-process.
    gtk4-layer-shell tracks the in-flight lock in a process-global
    (`current_lock` in session-lock.c) that is cleared only by the compositor's
    reply or by session_lock_unlock() -- and the latter is not exported from
    the shared library, so it is unreachable from Python. Until that global is
    cleared, every further lock attempt fails immediately, on a fresh
    GtkSessionLockInstance as much as on the original one: the very first thing
    session_lock_lock() does is bail out if `current_lock` is non-NULL.

    So the only way back to a usable state is a new process. The service unit
    restarts us on EXIT_TEMPFAIL after RestartSec, and the day the entry belongs
    to plus the overall deadline are carried forward in STATE_PATH, since a
    fresh process would otherwise re-stamp both from scratch.

    Stopping is bounded by wall-clock time rather than a restart count: the
    laptop suspends for hours at a time, so a count would say nothing about how
    long the prompt has actually been pending.
    """
    if time.time() + RETRY_INTERVAL_SECONDS >= RETRY_DEADLINE:
        print(f"{reason}; deadline reached, giving up.")
        exit_now(EXIT_DONE)

    print(f"{reason}; exiting for restart in {RETRY_INTERVAL_SECONDS // 60} min.")
    exit_now(EXIT_TEMPFAIL)


def prompt_label():
    """Label for the prompt question.

    On the same day the script was started it reads "today"; if the prompt only
    succeeds on a later day, it names the weekday the entry is actually for.
    """
    if date.today() == START_DATE:
        return "What did you do today ?"
    return f"What did you do on {START_DATE.strftime('%A')} ?"


class PromptWindow(Gtk.Window):
    def __init__(self, unlock):
        # Deliberately NOT attached to the Gtk.Application (no application=app).
        # gtk4-session-lock owns these windows and calls gtk_window_destroy() on
        # them itself when the lock ends. If they are also registered with the
        # application, that teardown drives gtk_application_window_removed ->
        # gdk_wayland_toplevel_remove_from_session on an already-destroyed session
        # surface, which asserts on GDK_IS_SURFACE and segfaults.
        super().__init__()
        self.unlock = unlock

        self.set_title("GTK4 Input Example")
        self.set_default_size(400, 200)

        # Layout box
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_halign(Gtk.Align.FILL)
        box.set_valign(Gtk.Align.CENTER)
        box.set_size_request(400, -1)
        self.set_child(box)

        # Label
        label = Gtk.Label(label=prompt_label())
        box.append(label)

        # Scrolled TextView
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_min_content_height(300)
        scrolled.set_min_content_width(400)
        scrolled.set_halign(Gtk.Align.CENTER)
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        box.append(scrolled)

        # Text view
        self.textview = Gtk.TextView()
        self.textview.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.textview.set_name("my_textinput")
        scrolled.set_child(self.textview)

        # Add key controller for Enter / Shift+Enter
        key_controller = Gtk.EventControllerKey()
        key_controller.connect("key-pressed", self._on_key_pressed)
        self.textview.add_controller(key_controller)

        # Connect text change callback to TextBuffer signal
        self.buffer = self.textview.get_buffer()
        self.buffer.connect("changed", self._on_text_changed)

        # Submit button
        self.button = Gtk.Button(label="Submit")
        self.button.set_sensitive(False)
        self.button.connect("clicked", self._on_submit_clicked)
        self.button.set_hexpand(False)
        self.button.set_halign(Gtk.Align.CENTER)
        box.append(self.button)

        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(b"""
            #my_textinput {
                border: 1px solid #888;
                border-radius: 4px;
                padding: 4px;
                background-color: white;
            }
            #my_textinput:focus {
                border-color: #1E90FF;
            }
        """)

        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def get_text(self):
        """Retrieve all text from TextView."""
        start, end = self.buffer.get_bounds()
        return self.buffer.get_text(start, end, True).strip()

    def enough_text(self):
        """Check if text meets minimum requirements."""
        text = self.get_text()
        word_count = len(text.split())
        char_count = len(text)
        return word_count >= 4 and char_count >= 20

    def _on_key_pressed(self, controller, keyval, keycode, state):
        """Handle Enter and Shift+Enter."""
        if keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            shift_pressed = bool(state & Gdk.ModifierType.SHIFT_MASK)

            if shift_pressed:
                # Insert newline manually
                buffer = self.textview.get_buffer()
                buffer.insert_at_cursor("\n")
            else:
                # Trigger submit
                self._on_submit_clicked(None)
            return True  # Disallow further key processing
        return False

    def _on_submit_clicked(self, button):
        if not self.enough_text():
            return

        try:
            log_file = Path.home() / "documents/tweag/timesheets.txt"
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            text = self.get_text()

            with log_file.open("a", encoding="utf-8") as f:
                f.write(f"\n[{timestamp}]\n{text}\n")
        finally:
            self.unlock()

    def _on_text_changed(self, entry):
        # Enable or disable the submit button based on text validity
        self.button.set_sensitive(self.enough_text())


class ScreenLock:
    def __init__(self):
        self.lock_instance = SessionLock.Instance.new()
        self.lock_instance.connect('locked', self._on_locked)
        self.lock_instance.connect('unlocked', self._on_unlocked)
        self.lock_instance.connect('failed', self._on_failed)
        self.lock_instance.connect('monitor', self._on_monitor)
        self.window = None
        # True once `locked` has fired for the in-flight lock() call. Monitors
        # that arrive before that are queued rather than assigned immediately,
        # since assigning to an unconfirmed lock silently produces no surface.
        self._locked = False
        self._pending_monitors = []
        self._confirm_timeout_id = None

    def _clear_confirm_timeout(self):
        if self._confirm_timeout_id is not None:
            GLib.source_remove(self._confirm_timeout_id)
            self._confirm_timeout_id = None

    def _on_locked(self, lock_instance):
        self._locked = True
        self._clear_confirm_timeout()
        for monitor in self._pending_monitors:
            self._assign(monitor)
        self._pending_monitors.clear()

    def _on_unlocked(self, lock_instance):
        # The prompt was answered (or dismissed): the retry loop is over, so
        # drop the carried-over deadline rather than leaving it for a later
        # session to trip over.
        clear_state()
        app.quit()

    def _on_failed(self, lock_instance):
        # Acquiring the session lock failed. This happens when another locker
        # already holds the screen (e.g. swaylock). The old Layer Shell fallback
        # does not work while the screen is locked, so instead we keep retrying
        # the lock, hoping the other locker eventually goes away, and give up
        # after a bounded amount of time.
        #
        # The retry has to go through a fresh process: this signal can be raised
        # by the library refusing to reuse an instance, and in every failure
        # path the process-global in-flight lock may still be set. See
        # restart_for_retry().
        self._locked = False
        self._pending_monitors.clear()
        self._clear_confirm_timeout()
        restart_for_retry("Session lock unavailable")

    def _on_confirm_timeout(self):
        # Neither `locked` nor `failed` showed up in time -- the compositor is
        # stuck (observed right after resuming from sleep). Nothing can be
        # retried in this process: the lock request is still in flight as far as
        # the library is concerned, and it has no API to cancel it. Restart.
        self._confirm_timeout_id = None
        restart_for_retry(
            f"Session lock not confirmed within {LOCK_CONFIRM_TIMEOUT_SECONDS}s"
        )
        return GLib.SOURCE_REMOVE

    def _on_monitor(self, lock_instance, monitor):
        if not self._locked:
            # Lock not confirmed yet (or already un-confirmed by a timeout) --
            # queue this monitor and let _on_locked assign it once/if the lock
            # actually succeeds. Assigning now would hit "no current lock in
            # place" and leave an invisible, unmapped window.
            self._pending_monitors.append(monitor)
            return
        self._assign(monitor)

    def _assign(self, monitor):
        if not self.window:
            self.window = PromptWindow(self.unlock)
            window = self.window
        else:
            window = Gtk.Window()

        # Defer assignment out of the synchronous lock() call stack. The monitor
        # signal fires from within gtk_session_lock_instance_lock(); assigning
        # (and thus mapping) the window inline does a Wayland roundtrip during
        # which a rejected lock delivers "finished", tearing the window down
        # mid-map and emitting GDK_IS_TOPLEVEL/GDK_IS_SURFACE assertions. Running
        # the assignment from an idle callback lets lock() return first.
        def assign():
            if self._locked:
                self.lock_instance.assign_window_to_monitor(window, monitor)
            return GLib.SOURCE_REMOVE

        GLib.idle_add(assign)

    def unlock(self):
        self._clear_confirm_timeout()
        self.lock_instance.unlock()

    def lock(self):
        self._locked = False
        self._pending_monitors.clear()
        self._clear_confirm_timeout()
        self._confirm_timeout_id = GLib.timeout_add_seconds(
            LOCK_CONFIRM_TIMEOUT_SECONDS, self._on_confirm_timeout
        )
        self.lock_instance.lock()


def check_still_wanted():
    """Bail out before touching the compositor if this attempt is obsolete.

    Every process in the retry chain starts here. It exists because a restart
    can arrive long after its deadline: RestartSec counts in monotonic time,
    which does not advance while the laptop is suspended, whereas the deadline
    is wall-clock. Suspend on Friday evening and the retry queued for ten
    minutes later fires on Monday morning, tens of hours past the point where
    the prompt should have given up.

    Note there is deliberately no "is START_DATE still today?" test here. The
    state file cannot distinguish a fresh activation from a retry -- systemd
    offers nothing that survives a restart chain to tell them apart, and the
    calendar cannot either, since a retry that begins at 23:55 is on a new date
    ten minutes later while still being the same attempt. The deadline is the
    only honest signal: an attempt is live until it expires, whatever the date
    happens to have done in the meantime.
    """
    if time.time() >= RETRY_DEADLINE:
        print(f"Deadline for {START_DATE} passed; not prompting.")
        exit_now(EXIT_DONE)


check_still_wanted()

app = Gtk.Application(application_id='com.github.wmww.gtk4-layer-shell.py-session-lock')
lock = ScreenLock()

def on_activate(app):
    # Hold the application alive for the whole session. Otherwise, when the lock
    # fails and no windows exist, GApplication would exit before we get a chance
    # to restart. Every exit path calls app.quit(), or exits outright, both of
    # which override holds.
    app.hold()
    lock.lock()

app.connect('activate', on_activate)
app.run(None)
