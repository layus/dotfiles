"""Core build/apply engine shared by `nix-update` and the `./rebuild` bootstrap.

This module is intentionally limited to the Python standard library and the
two external tools every code path already needs: `nix` and `git` (plus
`hostname`).  It deliberately avoids the "fancy" dependencies the full
`nix-update` CLI assumes -- inotify-tools, network fetches, argparse plumbing,
the waybar watcher and the status pretty-printer all live in `nix-update.py`.

The bootstrap (`./rebuild`) must run with whatever Python and tools the system
happens to provide, so anything it relies on belongs here.
"""

from __future__ import annotations

import concurrent.futures
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

# Canonical order for the "both" meta-target: home-manager first, then os.
TARGETS = ("hm", "os")


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
        if target == "os":
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

    def on_state_changed(self) -> None:
        """Hook invoked after any state file changes.

        No-op in the core engine (used as-is by the bootstrap).  The full CLI
        overrides this to refresh its waybar message files.
        """

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
        self.on_state_changed()

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

        "both" always means home-manager first, then os (see TARGETS).
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

    def _build_targets(self, target: str) -> int:
        """Build every expanded target.

        Builds are independent (separate flake assemblies, store paths, state
        and log files), so when more than one target is requested they run in
        parallel.  A single target builds inline.  Returns the last non-zero rc.
        """
        targets = self._expand(target)
        if len(targets) <= 1:
            return self._run_targets(target, self._build_one)

        print(f"=== Building {', '.join(targets)} in parallel ===")
        rc = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(targets)) as pool:
            futures = {pool.submit(self._build_one, t): t for t in targets}
            for fut in concurrent.futures.as_completed(futures):
                if fut.result() != 0:
                    rc = fut.result()
        return rc

    def cmd_build(self, target: str) -> int:
        return self._build_targets(target)

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
        if status != "ready" and not (target == "os" and do_switch and status == "pending"):
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
        if target == "os":
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
        self.on_state_changed()

        print(f"{target}: applied successfully ({result})")
        return 0

    def cmd_apply(self, target: str, do_rebuild: bool, do_switch: bool) -> int:
        # Builds are independent and may run in parallel, but activation must
        # stay sequential and in canonical order (home-manager before os).
        # So when rebuilding multiple targets, build them all in parallel first,
        # then activate each one in order without rebuilding again.
        if do_rebuild and len(self._expand(target)) > 1:
            rc = self._build_targets(target)
            if rc != 0:
                return rc
            do_rebuild = False
        return self._run_targets(
            target, lambda t: self._apply_one(t, do_rebuild, do_switch)
        )

    def cmd_switch(self, target: str, do_rebuild: bool) -> int:
        return self.cmd_apply(target, do_rebuild, True)
