#!/usr/bin/env python3

# For GTK4 Layer Shell to get linked before libwayland-client we must explicitly load it before importing with gi
from ctypes import CDLL
CDLL('libgtk4-layer-shell.so')

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4SessionLock', '1.0')

from gi.repository import Gtk
from gi.repository import Gdk
from gi.repository import Gtk4SessionLock as SessionLock

from datetime import datetime
from pathlib import Path


class PromptWindow(Gtk.Window):
    def __init__(self, unlock):
        super().__init__(application=app)
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
        label = Gtk.Label(label="What did you do today ?")
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

        # Connect text changes callback to proper buffer signal
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
        """Retrieve all text from the TextView buffer."""
        start, end = self.buffer.get_bounds()
        return self.buffer.get_text(start, end, True).strip()

    def enough_text(self):
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
            return True  # Stop further processing
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
        # Make button senistive to hint that there is enough text
        self.button.set_sensitive(self.enough_text())

class ScreenLock:
    def __init__(self):
        self.lock_instance = SessionLock.Instance.new()
        self.lock_instance.connect('locked', self._on_locked)
        self.lock_instance.connect('unlocked', self._on_unlocked)
        self.lock_instance.connect('failed', self._on_failed)
        self.lock_instance.connect('monitor', self._on_monitor)
        self.window = None

    def _on_locked(self, lock_instance):
        pass

    def _on_unlocked(self, lock_instance):
        app.quit()

    def _on_failed(self, lock_instance):
        app.quit()

    def _on_monitor(self, lock_instance, monitor):
        if not self.window:
            self.window = PromptWindow(self.unlock)
            window = self.window
        else:
            window = Gtk.Window(application=app)

        lock_instance.assign_window_to_monitor(window, monitor)

    def unlock(self):
        self.lock_instance.unlock()

    def lock(self):
        self.lock_instance.lock()

app = Gtk.Application(application_id='com.github.wmww.gtk4-layer-shell.py-session-lock')
lock = ScreenLock()

def on_activate(app):
    lock.lock()

app.connect('activate', on_activate)
app.run(None)
