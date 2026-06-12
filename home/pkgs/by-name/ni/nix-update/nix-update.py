#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


UPDATE_INPUTS = ["nixpkgs", "homeManager", "nixvim"]


class NixUpdateError(RuntimeError):
    pass


@dataclass
class TargetContext:
    target: str
    attr: str
    current: Path
    state_file: Path
    log_file: Path
    result_link: Path
    lock_file: Path
    gc_root: Path


class App:
    def __init__(self, flake_dir: Path):
        self.flake_dir = flake_dir
        self.host = self._run(["hostname"], capture=True).strip()
        self.user = os.environ.get("USER", "")
        self.uid = os.getuid()

        runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{self.uid}"))
        self.state_dir = runtime_dir
        self.log_dir = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "nix-update"
        self.log_dir.mkdir(parents=True, exist_ok=True)

        self.override_inputs = []
        local_cfg = self.flake_dir / "local"
        if local_cfg.is_dir():
            self.override_inputs = ["--override-input", "localConfig", f"path:{local_cfg}"]

        self.hm_config = self._resolve_hm_config()

    def _run(
        self,
        cmd: list[str],
        *,
        capture: bool = False,
        check: bool = True,
        cwd: Path | None = None,
    ) -> str:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd or self.flake_dir),
            check=False,
            text=True,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
        )
        if check and proc.returncode != 0:
            raise NixUpdateError(
                f"Command failed ({proc.returncode}): {' '.join(cmd)}\n{(proc.stderr or '').strip()}"
            )
        return proc.stdout or ""

    def _run_streaming(self, cmd: list[str], log_file: Path) -> int:
        with log_file.open("a", encoding="utf-8") as log:
            process = subprocess.Popen(
                cmd,
                cwd=str(self.flake_dir),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            assert process.stdout is not None
            for line in process.stdout:
                sys.stdout.write(line)
                log.write(line)
            return process.wait()

    def _git(self, *args: str, check: bool = True) -> str:
        return self._run(["git", "-C", str(self.flake_dir), *args], capture=True, check=check)

    def is_tree_dirty(self) -> bool:
        proc1 = subprocess.run(
            ["git", "-C", str(self.flake_dir), "diff", "--quiet", "--", ":!.verified-rev"],
            check=False,
        )
        if proc1.returncode != 0:
            return True
        proc2 = subprocess.run(["git", "-C", str(self.flake_dir), "diff", "--cached", "--quiet"], check=False)
        return proc2.returncode != 0

    def require_clean_tree(self) -> str:
        if self.is_tree_dirty():
            raise NixUpdateError("ERROR: Flake directory has uncommitted changes. Commit first.")
        rev = self._git("rev-parse", "HEAD").strip()
        if not rev:
            raise NixUpdateError("ERROR: Could not determine git revision.")
        return rev

    def stamp_verified_rev(self, rev: str) -> None:
        (self.flake_dir / ".verified-rev").write_text(rev + "\n", encoding="utf-8")

    def clear_verified_rev(self) -> None:
        (self.flake_dir / ".verified-rev").write_text("", encoding="utf-8")

    def _resolve_hm_config(self) -> str:
        hm_config = f"{self.user}@{self.host}"
        cmd = [
            "nix",
            "eval",
            f"{self.flake_dir}#homeConfigurations.\"{hm_config}\"",
            "--no-write-lock-file",
            *self.override_inputs,
            "--apply",
            "x: true",
        ]
        proc = subprocess.run(cmd, cwd=str(self.flake_dir), check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if proc.returncode == 0:
            return hm_config
        return self.user

    def resolve_target(self, target: str) -> TargetContext:
        if target == "nixos":
            attr = f"nixosConfigurations.{self.host}.config.system.build.toplevel"
            current = Path("/run/current-system")
        elif target == "hm":
            attr = f'homeConfigurations."{self.hm_config}".activationPackage'
            current = Path.home() / ".local/state/nix/profiles/home-manager"
            fallback = Path.home() / ".local/state/home-manager/gcroots/current-home"
            if not current.exists() and fallback.exists():
                current = fallback
        else:
            raise NixUpdateError(f"Unknown target: {target}")

        state_file = self.state_dir / f"nix-update-{target}.json"
        return TargetContext(
            target=target,
            attr=attr,
            current=current,
            state_file=state_file,
            log_file=self.log_dir / f"{target}.log",
            result_link=self.log_dir / f"result-{target}",
            lock_file=self.log_dir / f"flake-lock-{target}.json",
            gc_root=Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
            / "nix"
            / "gcroots"
            / f"nix-update-{target}",
        )

    def write_state(self, ctx: TargetContext, status: str, result: str = "", diff_summary: str = "", error: str = "") -> None:
        payload = {
            "status": status,
            "result": result,
            "diff_summary": diff_summary,
            "error": error,
            "lock_file": str(ctx.lock_file),
            "timestamp": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        }
        ctx.state_file.write_text(json.dumps(payload), encoding="utf-8")

    def read_state(self, ctx: TargetContext) -> dict[str, str] | None:
        if not ctx.state_file.exists():
            return None
        try:
            return json.loads(ctx.state_file.read_text(encoding="utf-8"))
        except Exception as exc:
            raise NixUpdateError(f"Invalid state file {ctx.state_file}: {exc}")

    def run_nix_build(self, ctx: TargetContext, extra_flags: Iterable[str]) -> int:
        cmd = [
            "nix",
            "build",
            f"{self.flake_dir}#{ctx.attr}",
            "--no-write-lock-file",
            *self.override_inputs,
            *extra_flags,
        ]
        return self._run_streaming(cmd, ctx.log_file)

    def cmd_build(self, target: str) -> int:
        if target == "both":
            raise NixUpdateError("build does not support 'both'; use 'hm' or 'nixos'.")
        ctx = self.resolve_target(target)

        dirty = self.is_tree_dirty()
        verified_rev = ""
        if dirty:
            print("WARNING: Flake directory is dirty - build will be marked as non-activatable.", file=sys.stderr)
        else:
            verified_rev = self._git("rev-parse", "HEAD").strip()
            if not verified_rev:
                raise NixUpdateError("ERROR: Could not determine git revision.")

        self.stamp_verified_rev(verified_rev)
        self.write_state(ctx, "building")
        ctx.log_file.write_text(
            f"=== nix-update build ({target}) started at {dt.datetime.now().ctime()} ===\n",
            encoding="utf-8",
        )
        if dirty:
            with ctx.log_file.open("a", encoding="utf-8") as log:
                log.write("WARNING: dirty build\n")

        flags = []
        for inp in UPDATE_INPUTS:
            flags.extend(["--update-input", inp])
        flags.extend(
            [
                "--out-link",
                str(ctx.result_link),
                "--output-lock-file",
                str(ctx.lock_file),
                "--log-format",
                "bar-with-logs",
            ]
        )

        rc = self.run_nix_build(ctx, flags)
        if rc != 0:
            err_tail = ""
            if ctx.log_file.exists():
                lines = ctx.log_file.read_text(encoding="utf-8", errors="replace").splitlines()
                err_tail = "\n".join(lines[-20:])
            self.clear_verified_rev()
            self.write_state(ctx, "failed", error=err_tail)
            with ctx.log_file.open("a", encoding="utf-8") as log:
                log.write("Build failed.\n")
            return rc

        result = str(ctx.result_link.resolve())
        ctx.gc_root.parent.mkdir(parents=True, exist_ok=True)
        self._run(["nix-store", "--add-root", str(ctx.gc_root), "--realise", result])

        diff_summary = ""
        if ctx.current.exists():
            proc = subprocess.run(
                ["nix", "store", "diff-closures", str(ctx.current), result],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )
            if proc.stdout:
                diff_summary = "\n".join(proc.stdout.splitlines()[:30])

        current_real = str(ctx.current.resolve()) if ctx.current.exists() else ""
        if dirty:
            self.write_state(ctx, "dirty", result=result, diff_summary=diff_summary)
            with ctx.log_file.open("a", encoding="utf-8") as log:
                log.write(f"Dirty build complete: {result} (will NOT be activated)\n")
        elif current_real and current_real == result:
            self.write_state(ctx, "current", result=result)
            with ctx.log_file.open("a", encoding="utf-8") as log:
                log.write("Already up to date.\n")
        else:
            self.write_state(ctx, "ready", result=result, diff_summary=diff_summary)
            with ctx.log_file.open("a", encoding="utf-8") as log:
                log.write(f"Build ready: {result}\n")

        self.clear_verified_rev()
        return 0

    def _apply_one(self, target: str, do_rebuild: bool, do_switch: bool) -> int:
        ctx = self.resolve_target(target)

        if do_rebuild:
            print(f"=== Rebuilding {target} before apply ===")
            rc = self.cmd_build(target)
            if rc != 0:
                return rc

        state = self.read_state(ctx)
        if state is None:
            print(f"No state file for {target} - run 'nix-update {target} build' first.")
            return 1

        status = state.get("status", "")
        if status == "dirty":
            print(f"{target}: build was from a dirty tree - refusing to activate. Commit and rebuild first.")
            return 1
        if status != "ready" and not (target == "nixos" and do_switch and status == "pending"):
            print(f"{target}: status is '{status}', not 'ready'. Nothing to apply.")
            return 1

        print(f"=== Applying {target} update ===")

        result = state.get("result", "")
        if not result or result == "null":
            print(f"{target}: state has no result path; rebuild first.")
            return 1

        result_path = Path(result)
        if not result_path.exists():
            print(f"{target}: result path does not exist: {result}")
            return 1

        verified_rev = self.require_clean_tree()
        self.stamp_verified_rev(verified_rev)

        new_status = "current"
        if target == "nixos":
            if do_switch:
                print(f"Running: prebuilt switch from {result}")
                rc = subprocess.run(["sudo", f"{result}/bin/switch-to-configuration", "switch"], check=False).returncode
            else:
                print(f"Running: prebuilt boot from {result}")
                rc = subprocess.run(["sudo", f"{result}/bin/switch-to-configuration", "boot"], check=False).returncode
                new_status = "pending"
        else:
            print(f"Running: prebuilt home activation from {result}")
            rc = subprocess.run([f"{result}/activate"], check=False).returncode

        if rc != 0:
            self.clear_verified_rev()
            return rc

        state["status"] = new_status
        state["timestamp"] = dt.datetime.now().astimezone().isoformat(timespec="seconds")
        ctx.state_file.write_text(json.dumps(state), encoding="utf-8")

        self.clear_verified_rev()
        print(f"{target}: applied successfully ({result})")
        return 0

    def cmd_apply(self, target: str, do_rebuild: bool, do_switch: bool) -> int:
        if target == "both":
            rc1 = self._apply_one("nixos", do_rebuild, do_switch)
            rc2 = self._apply_one("hm", do_rebuild, do_switch)
            return 0 if (rc1 == 0 or rc2 == 0) else 1
        if target not in {"nixos", "hm"}:
            raise NixUpdateError(f"Unknown target: {target}")
        return self._apply_one(target, do_rebuild, do_switch)

    def cmd_switch(self, target: str, do_rebuild: bool) -> int:
        return self.cmd_apply(target, do_rebuild, True)

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

    def cmd_waybar(self, scope: str = "both") -> int:
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
            payload = {
                "text": f"❄{self._status_icon(nixos_status)}",
                "tooltip": read_tooltip("nixos"),
                "class": self._status_class((nixos_status,)),
            }
        elif scope == "hm":
            payload = {
                "text": f"🏠{self._status_icon(hm_status)}",
                "tooltip": read_tooltip("hm"),
                "class": self._status_class((hm_status,)),
            }
        else:
            payload = {
                "text": f"❄{self._status_icon(nixos_status)} 🏠{self._status_icon(hm_status)}",
                "tooltip": read_tooltip("nixos") + "\n" + read_tooltip("hm"),
                "class": self._status_class((nixos_status, hm_status)),
            }
        print(json.dumps(payload))
        return 0

    def cmd_status(self, scope: str = "both") -> int:
        print()
        print("+---------------------------+")
        print("|     nix-update status     |")
        print("+---------------------------+")
        print()

        targets = ("nixos", "hm") if scope == "both" else (scope,)

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
        print("  nix-update <nixos|hm> build")
        print("  nix-update <nixos|hm|both> apply [--rebuild]")
        print("  nix-update <nixos|hm|both> switch [--rebuild]")
        print("  nix-update <nixos|hm|both> status")
        print("  nix-update <nixos|hm|both> waybar")
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
        return app.cmd_build(target)
    if subcmd == "apply":
        do_rebuild, do_switch = parse_flags(rest, {"rebuild", "switch"})
        return app.cmd_apply(target, do_rebuild, do_switch)
    if subcmd == "switch":
        do_rebuild, _ = parse_flags(rest, {"rebuild"})
        return app.cmd_switch(target, do_rebuild)
    if subcmd == "status":
        if rest:
            raise NixUpdateError(f"Unknown argument(s): {' '.join(rest)}")
        return app.cmd_status(target)
    if subcmd == "waybar":
        if rest:
            raise NixUpdateError(f"Unknown argument(s): {' '.join(rest)}")
        return app.cmd_waybar(target)

    raise NixUpdateError(f"Unknown command: {subcmd}")


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except NixUpdateError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
