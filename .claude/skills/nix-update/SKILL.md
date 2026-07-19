---
name: nix-update
description: Build and apply NixOS / home-manager updates in this repo with the nix-update command. Use whenever asked to rebuild, switch, apply, or activate the system or home configuration.
---

# Applying configuration changes with nix-update

This repo uses a custom `nix-update` tool (source: `pkgs/by-name/ni/nix-update/`)
to build and activate the NixOS and home-manager configurations.

## Usage

```
nix-update <os|hm|both> [build|apply|switch|status|waybar]
```

- `os` = NixOS system config, `hm` = home-manager, `both` = both.
- `build`  — build the configuration (no activation).
- `apply`  — activate a previously built result.
- `switch` — build + activate.
- `status` — show state of the last build.

Typical commands:

```sh
nix-update hm switch     # rebuild and activate home-manager
nix-update os switch     # rebuild and activate NixOS (boot activation)
nix-update both build    # build everything without activating
```

## IMPORTANT: commit BEFORE applying

`nix-update` refuses to **activate** from a dirty git tree:

- A build from a dirty tree is marked "non-activatable"; `apply` will fail
  with "build was from a dirty tree - refusing to activate. Commit and
  rebuild first."
- Some operations abort outright with "Flake directory has uncommitted
  changes. Commit first."

So the workflow when changing this config is always:

1. Edit the configuration.
2. Optionally `nix-update <target> build` to test the build (works dirty,
   with a warning).
3. `git add` + `git commit` (a nixpkgs-fmt pre-commit hook runs; if it
   reformats files, re-add and commit again).
4. `nix-update <target> switch` (or `apply` if already built after the
   commit).

## Bootstrap fallback

If `nix-update` itself is broken or not installed, use `./rebuild <hm|nixos|both>`
at the repo root. It reuses the same library but always builds from the
committed flake.lock (tracked inputs are not updated).

## Automation

Systemd user timers `nix-update-os` / `nix-update-hm` (see
`home/modules/nix-update.nix`, option `services.nix-update.targets`)
periodically run builds in the background; pending updates show up in the
waybar/motd status.
