#!/usr/bin/env python3

"""`nix-update` command-line front-end.

The build/apply engine lives in `nix_update_lib` (standard library + `nix` and
`git` only).  This module layers on the features that assume richer
dependencies or interactivity and are *not* needed by the `./rebuild`
bootstrap: the upstream fast-forward check (network), the waybar message files
and their inotify-based watcher (inotify-tools), the status pretty-printer and
the argparse command-line interface.
"""

from __future__ import annotations

import argparse
import json
import os
import select
import shutil
import subprocess
import sys
import termios
import time
import tty
from pathlib import Path

from nix_update_lib import App as CoreApp, NixUpdateError


class App(CoreApp):
    """Core engine plus the interactive / waybar / network features."""

    def ensure_up_to_date(self) -> None:
        """Fetch upstream and fast-forward the checkout before rebuilding.

        Always runs before a build/apply so we never rebuild against a stale
        checkout. Errors out when the local branch has diverged from upstream
        (a fast-forward is impossible), leaving resolution to the user.
        """
        upstream = self._git(
            "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}", check=False
        ).strip()
        if not upstream:
            print("==> No upstream tracking branch configured; skipping up-to-date check.")
            return

        print(f"==> Fetching {upstream} ...")
        self._git("fetch", "--quiet")

        local = self._git("rev-parse", "HEAD").strip()
        remote = self._git("rev-parse", "@{u}").strip()
        if local == remote:
            return

        base = self._git("merge-base", "HEAD", "@{u}").strip()
        if remote == base:
            # Local is ahead of upstream; nothing to pull.
            return
        if local != base:
            raise NixUpdateError(
                "ERROR: Local branch has diverged from upstream; cannot fast-forward.\n"
                f"Reconcile with {upstream} (rebase/merge) before rebuilding."
            )

        print(f"==> Fast-forwarding to {upstream} ...")
        rc = subprocess.run(
            ["git", "-C", str(self.flake_dir), "merge", "--ff-only", "@{u}"],
            check=False,
        ).returncode
        if rc != 0:
            raise NixUpdateError(f"ERROR: Fast-forward to {upstream} failed.")

    def _status_icon(self, status: str) -> str:
        return {
            "failed": "✗",
            "dirty": "⚠",
            "building": "…",
            "ready": "⬆",
            "pending": "⏻",
            "current": "✓",
        }.get(status, "?")

    def _status_class(self, statuses: tuple[str, ...]) -> str:
        cls = "current"
        for s in statuses:
            if s == "failed":
                cls = "failed"
                break
            if s == "dirty" and cls != "failed":
                cls = "dirty"
            elif s == "building" and cls not in {"failed", "dirty"}:
                cls = "building"
            elif s == "pending" and cls not in {"failed", "dirty", "building"}:
                cls = "pending"
            elif s == "ready" and cls not in {"failed", "dirty", "building"}:
                cls = "ready"
        return cls

    # --- waybar -----------------------------------------------------------

    def on_state_changed(self) -> None:
        # Keep the waybar message files in sync with every state change.
        self.refresh_waybar()

    def cmd_waybar(self, scope: str = "both", watch: bool = False) -> int:
        if watch:
            return self._waybar_watch(scope)
        # One-shot: refresh the file and echo it (handy for manual testing).
        self._write_waybar(scope)
        sys.stdout.write(self._waybar_file(scope).read_text(encoding="utf-8"))
        return 0

    def _waybar_file(self, scope: str) -> Path:
        return self.state_dir / f"nix-update-waybar-{scope}.json"

    def _build_waybar_payload(self, scope: str) -> dict[str, str]:
        def read_status(name: str) -> str:
            f = self.state_dir / f"nix-update-{name}.json"
            if not f.exists():
                return "unknown"
            try:
                return json.loads(f.read_text(encoding="utf-8")).get("status", "unknown")
            except Exception:
                return "unknown"

        def read_tooltip(name: str) -> str:
            f = self.state_dir / f"nix-update-{name}.json"
            if not f.exists():
                return f"{name}: no data"
            try:
                data = json.loads(f.read_text(encoding="utf-8"))
                tip = f"{name}: {data.get('status', 'unknown')} ({data.get('timestamp', '')})"
                diff = data.get("diff_summary") or ""
                err = data.get("error") or ""
                if diff:
                    tip += "\n" + diff
                if err and data.get("status") == "failed":
                    tip += "\nerror: " + err
                return tip
            except Exception:
                return f"{name}: invalid state"

        nixos_status = read_status("nixos")
        hm_status = read_status("hm")

        if scope == "nixos":
            return {
                "text": f"❄{self._status_icon(nixos_status)}",
                "tooltip": read_tooltip("nixos"),
                "class": self._status_class((nixos_status,)),
            }
        if scope == "hm":
            return {
                "text": f"🏠{self._status_icon(hm_status)}",
                "tooltip": read_tooltip("hm"),
                "class": self._status_class((hm_status,)),
            }
        return {
            "text": f"❄{self._status_icon(nixos_status)} 🏠{self._status_icon(hm_status)}",
            "tooltip": read_tooltip("nixos") + "\n" + read_tooltip("hm"),
            "class": self._status_class((nixos_status, hm_status)),
        }

    def _write_waybar(self, scope: str) -> None:
        """Write the rendered waybar message for `scope` to its file.

        Written in place: waybar (and our own watcher) only read on the
        `close_write` inotify event, so they never observe a partial line.
        """
        line = json.dumps(self._build_waybar_payload(scope)) + "\n"
        self._waybar_file(scope).write_text(line, encoding="utf-8")

    def refresh_waybar(self) -> None:
        """Update every waybar message file. Best-effort: never fails a build."""
        for scope in ("nixos", "hm", "both"):
            try:
                self._write_waybar(scope)
            except Exception:
                pass

    def _waybar_watch(self, scope: str) -> int:
        """Continuous waybar module: emit the message file, then re-emit on change.

        A one-shot `inotifywait` would race: a write landing between our read
        and the next wait call would go unnoticed. Instead we start
        `inotifywait -m` (monitor mode) *before* the first read, so the watch is
        already established when we emit. Each event then triggers a re-emit,
        and a burst of writes is drained into a single emit of the latest value.
        Falls back to slow polling when inotifywait is unavailable.
        """
        f = self._waybar_file(scope)

        def emit() -> None:
            try:
                line = f.read_text(encoding="utf-8").strip()
            except FileNotFoundError:
                self._write_waybar(scope)
                line = f.read_text(encoding="utf-8").strip()
            sys.stdout.write(line + "\n")
            sys.stdout.flush()

        inotifywait = shutil.which("inotifywait")
        if not inotifywait:
            self._write_waybar(scope)
            emit()
            while True:
                time.sleep(5)
                emit()

        # The file must exist before inotifywait can watch it. Our writer edits
        # the file in place (no inode swap), so watching the file directly is
        # safe and survives across writes.
        self._write_waybar(scope)
        proc = subprocess.Popen(
            [inotifywait, "-m", "-q", "-e", "close_write", str(f)],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        try:
            # Monitor is now live; emit the current value. Any write that raced
            # the startup above is reflected here, and any write from now on
            # produces an event we consume below -- so nothing is missed.
            emit()
            assert proc.stdout is not None
            for first in proc.stdout:  # blocks until the next event
                if not first:
                    break
                # Drain events already queued so a burst collapses into one
                # emit of the latest file contents.
                while select.select([proc.stdout], [], [], 0)[0]:
                    if not proc.stdout.readline():
                        break
                emit()
        finally:
            proc.terminate()
        return 0

    # --- status -----------------------------------------------------------

    def cmd_status(self, scope: str = "both", show_commands: bool = True) -> int:
        print()
        print("+---------------------------+")
        print("|     nix-update status     |")
        print("+---------------------------+")
        print()

        targets = self._expand(scope) if scope == "both" else (scope,)

        for target in targets:
            ctx = self.resolve_target(target)
            print(f"--- {target} ---")
            state = self.read_state(ctx)
            if state is None:
                print("  No data (no builds have run yet)")
                print()
                continue

            status = state.get("status", "")
            timestamp = state.get("timestamp", "")
            result = state.get("result", "")
            diff_summary = state.get("diff_summary", "")
            error = state.get("error", "")

            print(f"  Status:    {status}")
            print(f"  Timestamp: {timestamp}")
            if status in {"ready", "pending"} and result:
                print(f"  Result:    {result}")
            if status == "pending":
                print("  (will activate on next boot)")

            if diff_summary:
                print("\n  Changes:")
                for line in diff_summary.splitlines():
                    print(f"    {line}")

            if status == "failed" and error:
                print("\n  Error (last 20 lines):")
                for line in error.splitlines():
                    print(f"    {line}")
                print(f"\n  Full log: {ctx.log_file}")

            print()

        if not show_commands:
            return 0

        print("--- Commands ---")
        print("  nix-update <nixos|hm|both> build")
        print("  nix-update <nixos|hm|both> apply [--rebuild]")
        print("  nix-update <nixos|hm|both> switch [--rebuild]")
        print("  nix-update <nixos|hm|both> status")
        print("  nix-update <nixos|hm|both> waybar [--watch]")
        print("  nix-update <nixos|hm> waybar --curses")
        print()
        return 0

    # --- interactive REPL (waybar click target) ---------------------------

    def cmd_curses(self, scope: str) -> int:
        """Minimal interactive loop for a single target (hm or nixos).

        A "glorified REPL": shows the current status, then offers build / apply
        / (nixos only) switch via an arrow-key menu, runs the chosen action with
        streaming output, and loops -- reprinting the status each time.  Not
        real curses; just raw-mode key reading so it works in any terminal
        opened by the waybar click.  Falls back to a typed prompt when stdin is
        not a tty.
        """
        if scope not in ("hm", "nixos"):
            raise NixUpdateError("--curses requires a single target: nixos or hm")

        # (label, action) -- action takes no args and returns an rc.
        actions: list[tuple[str, "callable"]] = [
            ("build", lambda: self._guarded(lambda: self.cmd_build(scope))),
            ("apply", lambda: self._guarded(lambda: self.cmd_apply(scope, do_rebuild=False, do_switch=False))),
        ]
        if scope == "nixos":
            actions.append(
                ("switch", lambda: self._guarded(lambda: self.cmd_switch(scope, do_rebuild=False)))
            )

        # Default to the most effectful action: switch (nixos) / apply (hm).
        default_label = "switch" if scope == "nixos" else "apply"
        selected = next(i for i, (label, _) in enumerate(actions) if label == default_label)

        title = {"hm": "home-manager", "nixos": "NixOS"}[scope]
        while True:
            self.cmd_status(scope, show_commands=False)
            selected = self._select_action(title, [label for label, _ in actions], selected)
            if selected is None:
                print()
                return 0

            label, fn = actions[selected]
            print(f"\n=== running {label} ===")
            try:
                fn()
            except NixUpdateError as exc:
                print(str(exc), file=sys.stderr)
            print()

    def _select_action(self, title: str, labels: list[str], default: int) -> "int | None":
        """Render an arrow-key menu and return the chosen index, or None to quit.

        Up/Down (or k/j) move the highlight, Enter runs the selection, a label's
        initial letter jumps to it, and q / Esc / Ctrl-C quit.  When stdin is
        not interactive, fall back to a plain typed prompt.
        """
        if not (sys.stdin.isatty() and sys.stdout.isatty()):
            return self._select_action_plain(title, labels, default)

        sel = default
        n = len(labels)
        print(f"=== {title} ===  (\u2191/\u2193 choose, Enter run, q quit)")
        rendered = False
        while True:
            if rendered:
                sys.stdout.write(f"\x1b[{n}A")  # move cursor back up over the menu
            rendered = True
            for i, label in enumerate(labels):
                marker = "\u2192" if i == sel else " "
                line = f" {marker} {label}"
                if i == sel:
                    line = f"\x1b[7m{line}\x1b[0m"
                sys.stdout.write(f"\x1b[2K{line}\n")
            sys.stdout.flush()

            key = self._read_key()
            if key in ("\x1b[A", "k"):
                sel = (sel - 1) % n
            elif key in ("\x1b[B", "j"):
                sel = (sel + 1) % n
            elif key in ("\r", "\n"):
                return sel
            elif key in ("q", "\x1b", "\x03", "\x04"):
                return None
            elif len(key) == 1:
                for i, label in enumerate(labels):
                    if label[:1].lower() == key.lower():
                        sel = i
                        break

    @staticmethod
    def _select_action_plain(title: str, labels: list[str], default: int) -> "int | None":
        keymap = {label[:1].lower(): i for i, label in enumerate(labels)}
        menu = "  ".join(f"[{label[:1]}] {label}" for label in labels)
        default_key = labels[default][:1]
        while True:
            print(f"=== {title} === {menu}  [q] quit")
            try:
                choice = input(f"> (default {default_key}) ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                print()
                return None
            if not choice:
                return default
            if choice in ("q", "quit", "exit"):
                return None
            if choice in keymap:
                return keymap[choice]
            print(f"Unknown choice: {choice!r}\n")

    @staticmethod
    def _read_key() -> str:
        """Read one keypress in raw mode, decoding arrow-key escape sequences."""
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            ch = os.read(fd, 1).decode(errors="ignore")
            if ch == "\x1b":
                # Pull any immediately-available continuation bytes (e.g. "[A").
                ready, _, _ = select.select([fd], [], [], 0.01)
                if ready:
                    ch += os.read(fd, 2).decode(errors="ignore")
            return ch
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)

    def _guarded(self, fn) -> int:
        """Run an action behind the same up-to-date check as the CLI does."""
        self.ensure_up_to_date()
        return fn()



def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="nix-update",
        add_help=True,
        usage="%(prog)s [--flake-dir PATH] <nixos|hm|both> [build|apply|switch|status|waybar] [options]",
    )
    parser.add_argument("--flake-dir", default=str(Path.home() / ".config/nixpkgs"), help="Path to the flake directory")
    parser.add_argument("target", help="nixos|hm|both")
    parser.add_argument("subcmd", nargs="?", default="apply")
    parser.add_argument("rest", nargs=argparse.REMAINDER)
    return parser.parse_args(argv)


def parse_flags(rest: list[str], allowed: set[str]) -> tuple[bool, bool]:
    do_rebuild = False
    do_switch = False
    for flag in rest:
        if flag == "--rebuild" and "rebuild" in allowed:
            do_rebuild = True
        elif flag == "--switch" and "switch" in allowed:
            do_switch = True
        else:
            raise NixUpdateError(f"Unknown flag: {flag}")
    return do_rebuild, do_switch


def main(argv: list[str]) -> int:
    ns = parse_args(argv)
    app = App(Path(ns.flake_dir).expanduser())

    target = ns.target
    subcmd = ns.subcmd
    rest = ns.rest

    if target not in {"nixos", "hm", "both"}:
        raise NixUpdateError(f"Unknown target: {target}")

    if subcmd == "build":
        if rest:
            raise NixUpdateError(f"Unknown argument(s): {' '.join(rest)}")
        app.ensure_up_to_date()
        return app.cmd_build(target)
    if subcmd == "apply":
        do_rebuild, do_switch = parse_flags(rest, {"rebuild", "switch"})
        app.ensure_up_to_date()
        return app.cmd_apply(target, do_rebuild, do_switch)
    if subcmd == "switch":
        do_rebuild, _ = parse_flags(rest, {"rebuild"})
        app.ensure_up_to_date()
        return app.cmd_switch(target, do_rebuild)
    if subcmd == "status":
        if rest:
            raise NixUpdateError(f"Unknown argument(s): {' '.join(rest)}")
        return app.cmd_status(target)
    if subcmd == "waybar":
        watch = False
        curses = False
        extra = list(rest)
        if "--watch" in extra:
            watch = True
            extra.remove("--watch")
        if "--curses" in extra:
            curses = True
            extra.remove("--curses")
        if extra:
            raise NixUpdateError(f"Unknown argument(s): {' '.join(extra)}")
        if watch and curses:
            raise NixUpdateError("--watch and --curses are mutually exclusive.")
        if curses:
            return app.cmd_curses(target)
        return app.cmd_waybar(target, watch=watch)

    raise NixUpdateError(f"Unknown command: {subcmd}")


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except NixUpdateError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
