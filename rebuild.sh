#!/usr/bin/env bash
# Bootstrap rebuild script — use when nix-update is not yet installed or broken.
# Usage:
#   ./rebuild.sh hm          # home-manager switch
#   ./rebuild.sh nixos        # sudo nixos-rebuild boot
#   ./rebuild.sh both         # both
set -euo pipefail

flake_dir="$(cd "$(dirname "$0")" && pwd)"
host="$(hostname)"
user="$USER"
target="${1:?Usage: $0 <hm|nixos|both>}"

# Check if Nix version is at least 2.32
check_nix_version() {
  local version
  version=$(nix --version | grep -oP '(?<=nix \(Nix\) )\d+\.\d+' || echo "0.0")
  local major minor
  major=$(echo "$version" | cut -d. -f1)
  minor=$(echo "$version" | cut -d. -f2)
  
  if [ "$major" -lt 2 ] || ([ "$major" -eq 2 ] && [ "$minor" -lt 32 ]); then
    return 1
  fi
  return 0
}

# Build and use a newer Nix if needed
ensure_nix_version() {
  if check_nix_version; then
    return 0
  fi
  
  echo "==> Nix version < 2.32 detected. Building Nix from flake..."
  
  echo "==> Building Nix..."
  nix_path=$(nix build "$flake_dir#nix^out" --no-link --print-out-paths) || {
    echo "ERROR: Could not build Nix from flake" >&2
    return 1
  }
  
  export PATH="$nix_path/bin:$PATH"
  echo "==> Using Nix from: $nix_path/bin"
}

ensure_nix_version

# Detect dirty tree (ignoring .verified-rev itself)
is_dirty=0
if ! git -C "$flake_dir" diff --quiet -- ':!.verified-rev' 2>/dev/null; then
  is_dirty=1
fi
if ! git -C "$flake_dir" diff --cached --quiet 2>/dev/null; then
  is_dirty=1
fi

if [ "$is_dirty" = 1 ]; then
  echo "WARNING: Flake directory is dirty — build will be marked as non-activatable." >&2
  verified_rev=""
else
  verified_rev="$(git -C "$flake_dir" rev-parse HEAD)"
fi

override_flags=()
if [ -d "$flake_dir/local" ]; then
  override_flags=(--override-input localConfig "path:$flake_dir/local")
fi

# Resolve HM config name: try user@host first, fall back to bare user
set -x
hm_config="$user@$host"
if ! nix eval "$flake_dir#homeConfigurations.\"$user@$host\"" --no-write-lock-file --apply 'x: true' 2>/dev/null; then
  hm_config="$user"
fi
set +x

stamp()  { echo "$verified_rev" > "$flake_dir/.verified-rev"; }
clear()  { : > "$flake_dir/.verified-rev"; }
trap clear EXIT

do_hm() {
  stamp
  if [ "$is_dirty" = 1 ]; then
    echo "==> [DIRTY BUILD] nix build $flake_dir#homeConfigurations.\"$hm_config\".activationPackage ${override_flags[*]}"
    nix build "$flake_dir#homeConfigurations.\"$hm_config\".activationPackage" --no-write-lock-file --no-link "${override_flags[@]}"
    echo "==> Dirty build complete. Use 'nix-update' or rebuild from a clean tree to activate."
  else
    echo "==> home-manager switch --flake $flake_dir#$hm_config ${override_flags[*]}"
    home-manager switch --flake "$flake_dir#$hm_config" --no-write-lock-file "${override_flags[@]}"
  fi
  clear
}

do_nixos() {
  stamp
  if [ "$is_dirty" = 1 ]; then
    echo "==> [DIRTY BUILD] nix build $flake_dir#nixosConfigurations.$host.config.system.build.toplevel ${override_flags[*]}"
    nix build "$flake_dir#nixosConfigurations.$host.config.system.build.toplevel" --no-write-lock-file --no-link "${override_flags[@]}"
    echo "==> Dirty build complete. Use 'nix-update' or rebuild from a clean tree to activate."
  else
    echo "==> sudo nixos-rebuild boot --flake $flake_dir#$host ${override_flags[*]}"
    sudo nixos-rebuild boot --flake "$flake_dir#$host" --no-write-lock-file "${override_flags[@]}"
  fi
  clear
}

case "$target" in
  hm)    do_hm ;;
  nixos) do_nixos ;;
  both)  do_nixos; do_hm ;;
  *)     echo "Unknown target: $target. Use hm, nixos, or both." >&2; exit 1 ;;
esac
