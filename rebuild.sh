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

# Enforce clean git tree (ignoring .verified-rev itself)
if ! git -C "$flake_dir" diff --quiet -- ':!.verified-rev' 2>/dev/null; then
  echo "ERROR: Flake directory has uncommitted changes. Commit first." >&2
  exit 1
fi
if ! git -C "$flake_dir" diff --cached --quiet 2>/dev/null; then
  echo "ERROR: Flake directory has staged but uncommitted changes. Commit first." >&2
  exit 1
fi
verified_rev="$(git -C "$flake_dir" rev-parse HEAD)"

override_flags=()
if [ -d "$flake_dir/local" ]; then
  override_flags=(--override-input localConfig "path:$flake_dir/local")
fi

stamp()  { echo "$verified_rev" > "$flake_dir/.verified-rev"; }
clear()  { : > "$flake_dir/.verified-rev"; }
trap clear EXIT

do_hm() {
  stamp
  echo "==> home-manager switch --flake $flake_dir#$user@$host ${override_flags[*]}"
  home-manager switch --flake "$flake_dir#$user@$host" "${override_flags[@]}"
  clear
}

do_nixos() {
  stamp
  echo "==> sudo nixos-rebuild boot --flake $flake_dir#$host ${override_flags[*]}"
  sudo nixos-rebuild boot --flake "$flake_dir#$host" "${override_flags[@]}"
  clear
}

case "$target" in
  hm)    do_hm ;;
  nixos) do_nixos ;;
  both)  do_nixos; do_hm ;;
  *)     echo "Unknown target: $target. Use hm, nixos, or both." >&2; exit 1 ;;
esac
