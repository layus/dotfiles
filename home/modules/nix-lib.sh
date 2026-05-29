# Shared nix command library — sourced by nix-update.sh and rebuild.sh.
# Expects these variables to be set by the caller:
#   flake_dir        — path to the flake (must be set before sourcing)
#   host             — hostname (must be set before sourcing)
#   user             — username (must be set before sourcing)

# Inputs to update (via --update-input) when building updates.
update_inputs=(nixpkgs homeManager nixvim)

# Inputs to override on every nix invocation.
override_inputs=()
if [ -d "$flake_dir/local" ]; then
  override_inputs=(--override-input localConfig "path:$flake_dir/local")
fi

# Resolve HM config name: try user@host first, fall back to bare user.
hm_config="$user@$host"
if ! nix eval "$flake_dir#homeConfigurations.\"$user@$host\"" \
    --no-write-lock-file "${override_inputs[@]}" --apply 'x: true' &>/dev/null; then
  hm_config="$user"
fi

# Resolve a target name to its flake attribute and current profile path.
_resolve_target() {
  local t="$1"
  case "$t" in
    nixos)
      attr="nixosConfigurations.$host.config.system.build.toplevel"
      current="/run/current-system"
      ;;
    hm)
      attr="homeConfigurations.\"$hm_config\".activationPackage"
      current="$HOME/.local/state/nix/profiles/home-manager"
      if [ ! -e "$current" ] && [ -e "$HOME/.local/state/home-manager/gcroots/current-home" ]; then
        current="$HOME/.local/state/home-manager/gcroots/current-home"
      fi
      ;;
    *) echo "Unknown target: $t" >&2; exit 1 ;;
  esac
}

# Build a flake attribute.
# Uses --no-write-lock-file (don't touch the repo's flake.lock).
# Caller passes extra flags (e.g. --update-input, --output-lock-file, --out-link).
run_nix_build() {
  local target="$1"; shift
  _resolve_target "$target"
  nix build "$flake_dir#$attr" \
    --no-write-lock-file \
    "${override_inputs[@]}" \
    "$@"
}

# Activate a configuration.
# Uses --no-update-lock-file (use committed lock exactly, don't resolve newer inputs)
# and --no-write-lock-file (don't write anything to the repo).
run_activate() {
  local target="$1" mode="$2"
  _resolve_target "$target"
  case "$target" in
    nixos)
      sudo nixos-rebuild "$mode" --flake "$flake_dir#$host" \
        --no-update-lock-file --no-write-lock-file "${override_inputs[@]}"
      ;;
    hm)
      home-manager switch --flake "$flake_dir#$hm_config" \
        --no-update-lock-file --no-write-lock-file "${override_inputs[@]}"
      ;;
  esac
}
