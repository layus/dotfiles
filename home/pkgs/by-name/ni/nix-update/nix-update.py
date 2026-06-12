#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


UPDATE_INPUTS = ["nixpkgs", "homeManager", "nixvim"]

# Canonical order for the "both" meta-target: home-manager first, then nixos.
TARGETS = ("hm", "nixos")


class NixUpdateError(RuntimeError):
    pass


def _make_writable(root: Path) -> None:
    """Recursively add user write permission to a tree."""
    for path in [root, *root.rglob("*")]:
        try:
            mode = path.lstat().st_mode
            os.chmod(path, mode | 0o200, follow_symlinks=False)
        except (FileNotFoundError, NotImplementedError, OSError):
            pass


def _force_rmtree(root: Path) -> None:
    """Remove a tree even if it contains read-only files/dirs."""

    def onexc(func, path, exc):
        try:
            os.chmod(path, 0o700)
        except OSError:
            pass
        func(path)

    try:
        shutil.rmtree(root, onexc=onexc)
    except TypeError:
        # Python < 3.12 fallback
        shutil.rmtree(root, onerror=lambda f, p, e: (os.chmod(p, 0o700), f(p)))



@dataclass
class TargetContext:
    target: str
    attr: str
    current: Path
    state_file: Path
    log_file: Path
    result_link: Path
    gc_root: Path


class App:
    def __init__(self, flake_dir: Path, *, update_refs: bool = True):
        self.flake_dir = flake_dir
        self.update_refs = update_refs
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
            gc_root=Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
            / "nix"
            / "gcroots"
            / f"nix-update-{target}",
        )

    def write_state(
        self,
        ctx: TargetContext,
        status: str,
        result: str = "",
        diff_summary: str = "",
        error: str = "",
        embedded_source: str = "",
    ) -> None:
        payload = {
            "status": status,
            "result": result,
            "diff_summary": diff_summary,
            "error": error,
            "embedded_source": embedded_source,
            "timestamp": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        }
        ctx.state_file.write_text(json.dumps(payload), encoding="utf-8")

    def _assemble_flake(self, dest: Path, verified_rev: str) -> None:
        """Assemble a fully self-contained flake in `dest`.

        The result is a directory that can be built on its own, with everything
        baked in so that the build's `self.outPath` (embedded via the
        config-integrity modules) is a real, rebuildable copy of the sources:

        - copies the flake tree (excluding .git/result/.direnv/__pycache__);
        - bakes the machine-local overlay into ./local-default, so the default
          `localConfig.url = "path:./local-default"` resolves to it with no
          `--override-input` needed at build or rebuild time;
        - writes .verified-rev (the clean git rev, or empty when dirty) which
          the config-integrity modules read from `self.outPath`; and
        - updates the lockfile so it pins the effective inputs.
        """
        shutil.copytree(
            self.flake_dir,
            dest,
            symlinks=False,
            ignore=shutil.ignore_patterns(".git", ".direnv", "result", "__pycache__"),
            dirs_exist_ok=True,
        )
        _make_writable(dest)

        # Bake localConfig: overwrite ./local-default with the real ./local
        # overlay so the default flake input resolves to it.
        local_src = self.flake_dir / "local"
        if local_src.is_dir():
            local_default = dest / "local-default"
            if local_default.exists():
                _force_rmtree(local_default)
            shutil.copytree(
                local_src,
                local_default,
                symlinks=False,
                ignore=shutil.ignore_patterns(".git", ".direnv", "result", "__pycache__"),
            )
            _make_writable(local_default)

        # Mark clean/dirty for the config-integrity modules, which read
        # `<self.outPath>/.verified-rev`.
        (dest / ".verified-rev").write_text(
            (verified_rev + "\n") if verified_rev else "", encoding="utf-8"
        )

        # Update the lockfile in the assembled tree (writes dest/flake.lock).
        # localConfig is always relocked because its content (./local-default)
        # changed.  Tracked inputs are bumped only when update_refs is set;
        # otherwise we keep the committed (known-good) lock for them, which is
        # what the bootstrap rebuild relies on.
        update_args = ["localConfig"]
        if self.update_refs:
            update_args = [*UPDATE_INPUTS, "localConfig"]
        self._run(["nix", "flake", "update", *update_args], cwd=dest)

    def _build_flake(
        self,
        ctx: TargetContext,
        flake_dir: Path,
        *,
        out_link: Path | None = None,
        log_file: Path | None = None,
    ) -> tuple[int, str]:
        """Build ctx.attr from a self-contained flake directory.

        No `--override-input` is used: the flake is expected to be fully
        assembled (localConfig baked into ./local-default, lock pinned).
        Returns (returncode, out_path).  Progress is streamed to stderr/console
        and, when given, appended to log_file.  The resulting store path is read
        from --print-out-paths on stdout.
        """
        cmd = [
            "nix",
            "build",
            f"{flake_dir}#{ctx.attr}",
            "--no-update-lock-file",
            "--no-write-lock-file",
            "--print-out-paths",
            "--log-format",
            "bar-with-logs",
        ]
        if out_link is not None:
            cmd.extend(["--out-link", str(out_link)])
        else:
            cmd.append("--no-link")

        proc = subprocess.Popen(
            cmd,
            cwd=str(flake_dir),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        assert proc.stderr is not None and proc.stdout is not None
        log_fh = open(log_file, "a", encoding="utf-8") if log_file else None
        try:
            for line in proc.stderr:
                sys.stderr.write(line)
                if log_fh:
                    log_fh.write(line)
        finally:
            if log_fh:
                log_fh.close()
        out = proc.stdout.read()
        rc = proc.wait()
        paths = [l.strip() for l in out.splitlines() if l.strip().startswith("/nix/store/")]
        return rc, (paths[-1] if paths else "")

    def _flake_store_path(self, flake_dir: Path) -> str:
        """Return the store path of the flake source (i.e. its `self.outPath`)."""
        out = self._run(
            ["nix", "flake", "metadata", str(flake_dir), "--json"],
            capture=True,
            cwd=flake_dir,
        )
        try:
            data = json.loads(out)
        except json.JSONDecodeError as exc:
            raise NixUpdateError(f"Could not parse flake metadata: {exc}")
        path = data.get("path", "")
        if not path:
            raise NixUpdateError("flake metadata did not report a source path")
        return path

    def read_state(self, ctx: TargetContext) -> dict[str, str] | None:
        if not ctx.state_file.exists():
            return None
        try:
            return json.loads(ctx.state_file.read_text(encoding="utf-8"))
        except Exception as exc:
            raise NixUpdateError(f"Invalid state file {ctx.state_file}: {exc}")

    def _expand(self, target: str) -> list[str]:
        """Expand a target into the concrete targets to act on, in order.

        "both" always means home-manager first, then nixos (see TARGETS).
        """
        if target == "both":
            return list(TARGETS)
        if target in TARGETS:
            return [target]
        raise NixUpdateError(f"Unknown target: {target}")

    def _run_targets(self, target: str, fn) -> int:
        """Run fn for each expanded target; return the last non-zero rc (or 0)."""
        rc = 0
        for t in self._expand(target):
            r = fn(t)
            if r != 0:
                rc = r
        return rc

    def cmd_build(self, target: str) -> int:
        return self._run_targets(target, self._build_one)

    def _build_one(self, target: str) -> int:
        ctx = self.resolve_target(target)

        dirty = self.is_tree_dirty()
        verified_rev = ""
        if dirty:
            print("WARNING: Flake directory is dirty - build will be marked as non-activatable.", file=sys.stderr)
        else:
            verified_rev = self._git("rev-parse", "HEAD").strip()
            if not verified_rev:
                raise NixUpdateError("ERROR: Could not determine git revision.")

        self.write_state(ctx, "building")
        ctx.log_file.write_text(
            f"=== nix-update build ({target}) started at {dt.datetime.now().ctime()} ===\n",
            encoding="utf-8",
        )
        if dirty:
            with ctx.log_file.open("a", encoding="utf-8") as log:
                log.write("WARNING: dirty build\n")

        # Assemble a fully self-contained flake in a temp dir and build the
        # generation FROM it.  The assembled tree bakes in the machine-local
        # overlay (./local-default), the effective lock, and the clean/dirty
        # marker, so the build's `self.outPath` (embedded via config-integrity)
        # is a real, rebuildable copy of the sources -- no `--override-input`
        # needed now or at rebuild/verify time.
        assembled = Path(tempfile.mkdtemp(prefix=f"nix-update-{target}-"))
        try:
            self._assemble_flake(assembled, verified_rev)

            rc, result = self._build_flake(
                ctx, assembled, out_link=ctx.result_link, log_file=ctx.log_file
            )
            if rc != 0 or not result:
                err_tail = ""
                if ctx.log_file.exists():
                    lines = ctx.log_file.read_text(encoding="utf-8", errors="replace").splitlines()
                    err_tail = "\n".join(lines[-20:])
                self.write_state(ctx, "failed", error=err_tail)
                with ctx.log_file.open("a", encoding="utf-8") as log:
                    log.write("Build failed.\n")
                return rc or 1

            # The store copy of the assembled flake (== the build's self.outPath)
            # is embedded in the output and kept alive by result's gc root.
            embedded_source = self._flake_store_path(assembled)
        finally:
            _force_rmtree(assembled)

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
            self.write_state(
                ctx,
                "dirty",
                result=result,
                diff_summary=diff_summary,
                embedded_source=embedded_source,
            )
            with ctx.log_file.open("a", encoding="utf-8") as log:
                log.write(f"Dirty build complete: {result} (will NOT be activated)\n")
        elif current_real and current_real == result:
            self.write_state(
                ctx,
                "current",
                result=result,
                embedded_source=embedded_source,
            )
            with ctx.log_file.open("a", encoding="utf-8") as log:
                log.write("Already up to date.\n")
        else:
            self.write_state(
                ctx,
                "ready",
                result=result,
                diff_summary=diff_summary,
                embedded_source=embedded_source,
            )
            with ctx.log_file.open("a", encoding="utf-8") as log:
                log.write(f"Build ready: {result}\n")

        return 0

    def _apply_one(self, target: str, do_rebuild: bool, do_switch: bool) -> int:
        ctx = self.resolve_target(target)

        if do_rebuild:
            print(f"=== Rebuilding {target} before apply ===")
            rc = self._build_one(target)
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

        embedded_source = state.get("embedded_source", "")
        if not embedded_source:
            print(f"{target}: embedded source path is missing in state; rebuild first.")
            return 1
        embedded_path = Path(embedded_source)
        if not embedded_path.exists():
            print(f"{target}: embedded source path does not exist: {embedded_source}")
            return 1

        print(f"Verifying: rebuilding {target} from its embedded sources before deploy")
        rc_check, rebuilt_result = self._build_flake(ctx, embedded_path)
        if rc_check != 0 or not rebuilt_result:
            print(f"{target}: rebuild from embedded sources failed; refusing to deploy.")
            return 1
        if rebuilt_result != result:
            print(f"{target}: embedded rebuild mismatch; refusing to deploy.")
            print(f"  expected: {result}")
            print(f"  got:      {rebuilt_result}")
            return 1

        self.require_clean_tree()

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
            return rc

        state["status"] = new_status
        state["timestamp"] = dt.datetime.now().astimezone().isoformat(timespec="seconds")
        ctx.state_file.write_text(json.dumps(state), encoding="utf-8")

        print(f"{target}: applied successfully ({result})")
        return 0

    def cmd_apply(self, target: str, do_rebuild: bool, do_switch: bool) -> int:
        return self._run_targets(
            target, lambda t: self._apply_one(t, do_rebuild, do_switch)
        )

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
