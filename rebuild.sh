#!/usr/bin/env bash
# Bootstrap rebuild script — use when nix-updater is not yet installed or broken.
# Usage:
#   ./rebuild.sh hm          # home-manager switch
#   ./rebuild.sh nixos        # sudo nixos-rebuild boot
#   ./rebuild.sh both         # both
set -euo pipefail

flake_dir="$(cd "$(dirname "$0")" && pwd)"
host="$(hostname)"
user="$USER"
target="${1:?Usage: $0 <hm|nixos|both>}"

override_flags=()
if [ -d "$flake_dir/local" ]; then
  override_flags=(--override-input localConfig "path:$flake_dir/local")
fi

do_hm() {
  echo "==> home-manager switch --flake $flake_dir#$user@$host ${override_flags[*]}"
  home-manager switch --flake "$flake_dir#$user@$host" "${override_flags[@]}"
}

do_nixos() {
  echo "==> sudo nixos-rebuild boot --flake $flake_dir#$host ${override_flags[*]}"
  sudo nixos-rebuild boot --flake "$flake_dir#$host" "${override_flags[@]}"
}

case "$target" in
  hm)    do_hm ;;
  nixos) do_nixos ;;
  both)  do_nixos; do_hm ;;
  *)     echo "Unknown target: $target. Use hm, nixos, or both." >&2; exit 1 ;;
esac
