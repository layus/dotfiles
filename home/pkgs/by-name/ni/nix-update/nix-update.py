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
import select
import shutil
import subprocess
import sys
import time
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

    def cmd_status(self, scope: str = "both") -> int:
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

        print("--- Commands ---")
        print("  nix-update <nixos|hm|both> build")
        print("  nix-update <nixos|hm|both> apply [--rebuild]")
        print("  nix-update <nixos|hm|both> switch [--rebuild]")
        print("  nix-update <nixos|hm|both> status")
        print("  nix-update <nixos|hm|both> waybar [--watch]")
        print()
        return 0


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
        extra = list(rest)
        if "--watch" in extra:
            watch = True
            extra.remove("--watch")
        if extra:
            raise NixUpdateError(f"Unknown argument(s): {' '.join(extra)}")
        return app.cmd_waybar(target, watch=watch)

    raise NixUpdateError(f"Unknown command: {subcmd}")


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except NixUpdateError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
