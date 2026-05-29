#!/usr/bin/env bash
set -euo pipefail

host="$(hostname)"
user="$USER"
flake_dir="@flakeDir@"
cd "$flake_dir"
state_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/nix-update"
mkdir -p "$log_dir"

# Nix-injected flags (may be empty)
update_inputs=(@updateInputFlags@)
override_inputs=(@overrideInputFlags@)

# Resolve HM config name: try user@host first, fall back to bare user
hm_config="$user@$host"
if ! nix eval "$flake_dir#homeConfigurations.\"$user@$host\"" --no-write-lock-file --apply 'x: true' &>/dev/null; then
  hm_config="$user"
fi

# --- helpers ---

is_tree_dirty() {
  if ! git -C "$flake_dir" diff --quiet -- ':!.verified-rev' 2>/dev/null; then
    return 0
  fi
  if ! git -C "$flake_dir" diff --cached --quiet 2>/dev/null; then
    return 0
  fi
  return 1
}

require_clean_tree() {
  if is_tree_dirty; then
    echo "ERROR: Flake directory has uncommitted changes. Commit first." >&2
    exit 1
  fi
  verified_rev="$(git -C "$flake_dir" rev-parse HEAD 2>/dev/null || echo "")"
  if [ -z "$verified_rev" ]; then
    echo "ERROR: Could not determine git revision." >&2
    exit 1
  fi
}

stamp_verified_rev() {
  echo "$verified_rev" > "$flake_dir/.verified-rev"
}

clear_verified_rev() {
  : > "$flake_dir/.verified-rev"
}

resolve_target() {
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
  state_file="$state_dir/nix-update-$t.json"
  log_file="$log_dir/$t.log"
  result_link="$log_dir/result-$t"
  lock_file="$log_dir/flake-lock-$t.json"
}

write_state() {
  local status="$1" result="${2:-}" diff_summary="${3:-}" error="${4:-}"
  jq -n \
    --arg status "$status" \
    --arg result "$result" \
    --arg diff_summary "$diff_summary" \
    --arg error "$error" \
    --arg lock_file "$lock_file" \
    --arg timestamp "$(date -Iseconds)" \
    '{ status: $status, result: $result, diff_summary: $diff_summary, error: $error, lock_file: $lock_file, timestamp: $timestamp }' \
    > "$state_file"
}

# --- subcommands ---

cmd_build() {
  local target="$1"
  resolve_target "$target"

  local dirty=0
  if is_tree_dirty; then
    dirty=1
    echo "WARNING: Flake directory is dirty — build will be marked as non-activatable." >&2
    verified_rev=""
  else
    verified_rev="$(git -C "$flake_dir" rev-parse HEAD 2>/dev/null || echo "")"
    if [ -z "$verified_rev" ]; then
      echo "ERROR: Could not determine git revision." >&2
      exit 1
    fi
  fi

  stamp_verified_rev
  write_state "building"
  echo "=== nix-update build ($target) started at $(date) ===" > "$log_file"
  if [ "$dirty" = 1 ]; then
    echo "WARNING: dirty build" >> "$log_file"
  fi

  local -a build_flags=()
  for input in "${update_inputs[@]}"; do
    build_flags+=(--update-input "$input")
  done
  build_flags+=("${override_inputs[@]}")

  local interactive=0
  [ -t 1 ] && interactive=1

  if nix build \
      "$flake_dir#$attr" \
      "${build_flags[@]}" \
      --out-link "$result_link" \
      --output-lock-file "$lock_file" \
      --log-format bar-with-logs \
      2>&1 | if [ "$interactive" = 1 ]; then tee -a "$log_file"; else cat >> "$log_file"; fi; then

    result="$(readlink -f "$result_link")"

    diff_summary=""
    if [ -e "$current" ]; then
      diff_summary="$(nix store diff-closures "$current" "$result" 2>/dev/null | head -30 || true)"
    fi

    if [ "$dirty" = 1 ]; then
      write_state "dirty" "$result" "$diff_summary" ""
      echo "Dirty build complete: $result (will NOT be activated)" >> "$log_file"
    elif [ -e "$current" ] && [ "$(readlink -f "$current")" = "$result" ]; then
      write_state "current" "$result" "" ""
      echo "Already up to date." >> "$log_file"
    else
      write_state "ready" "$result" "$diff_summary" ""
      echo "Build ready: $result" >> "$log_file"
    fi
  else
    error="$(tail -20 "$log_file")"
    clear_verified_rev
    write_state "failed" "" "" "$error"
    echo "Build failed." >> "$log_file"
    return 1
  fi
  clear_verified_rev
}

cmd_apply() {
  local target="$1" do_rebuild="$2" do_switch="$3"

  apply_one() {
    local t="$1"
    resolve_target "$t"

    if [ "$do_rebuild" = "1" ]; then
      echo "=== Rebuilding $t before apply ==="
      cmd_build "$t"
    fi

    if [ ! -f "$state_file" ]; then
      echo "No state file for $t — run 'nix-update build $t' first."
      return 1
    fi

    local status
    status="$(jq -r .status "$state_file")"
    if [ "$status" = "dirty" ]; then
      echo "$t: build was from a dirty tree — refusing to activate. Commit and rebuild first."
      return 1
    fi
    if [ "$status" != "ready" ]; then
      echo "$t: status is '$status', not 'ready'. Nothing to apply."
      return 1
    fi

    echo "=== Applying $t update ==="

    require_clean_tree
    stamp_verified_rev

    local -a apply_flags=("${override_inputs[@]}")
    local new_status="current"

    case "$t" in
      nixos)
        if [ "$do_switch" = "1" ]; then
          echo "Running: sudo nixos-rebuild switch --flake $flake_dir#$host ${apply_flags[*]}"
          sudo nixos-rebuild switch --flake "$flake_dir#$host" "${apply_flags[@]}"
        else
          echo "Running: sudo nixos-rebuild boot --flake $flake_dir#$host ${apply_flags[*]}"
          sudo nixos-rebuild boot --flake "$flake_dir#$host" "${apply_flags[@]}"
          new_status="pending"
        fi
        ;;
      hm)
        echo "Running: home-manager switch --flake $flake_dir#$hm_config ${apply_flags[*]}"
        home-manager switch --flake "$flake_dir#$hm_config" "${apply_flags[@]}"
        ;;
    esac

    local result
    result="$(jq -r .result "$state_file")"
    jq --arg timestamp "$(date -Iseconds)" --arg new_status "$new_status" \
       '.status = $new_status | .timestamp = $timestamp' \
       "$state_file" > "$state_file.tmp" \
       && mv "$state_file.tmp" "$state_file"

    clear_verified_rev
    echo "$t: applied successfully ($result)"
  }

  case "$target" in
    both)
      apply_one nixos || true
      apply_one hm || true
      ;;
    nixos|hm)
      apply_one "$target"
      ;;
    *) echo "Unknown target: $target" >&2; exit 1 ;;
  esac
}

cmd_switch() {
  local target="$1" do_rebuild="$2"
  cmd_apply "$target" "$do_rebuild" 1
}

cmd_status() {
  show_target() {
    local t="$1"
    resolve_target "$t"

    echo "━━━ $t ━━━"
    if [ ! -f "$state_file" ]; then
      echo "  No data (no builds have run yet)"
      echo ""
      return
    fi

    local status timestamp diff_summary error result
    status="$(jq -r .status "$state_file")"
    timestamp="$(jq -r .timestamp "$state_file")"
    result="$(jq -r '.result // ""' "$state_file")"
    diff_summary="$(jq -r '.diff_summary // ""' "$state_file")"
    error="$(jq -r '.error // ""' "$state_file")"

    echo "  Status:    $status"
    echo "  Timestamp: $timestamp"

    if ([ "$status" = "ready" ] || [ "$status" = "pending" ]) && [ -n "$result" ]; then
      echo "  Result:    $result"
    fi

    if [ "$status" = "pending" ]; then
      echo "  (will activate on next boot)"
    fi

    if [ -n "$diff_summary" ] && [ "$diff_summary" != "null" ] && [ "$diff_summary" != "" ]; then
      echo ""
      echo "  Changes:"
      echo "    ${diff_summary//$'\n'/$'\n    '}"
    fi

    if [ "$status" = "failed" ] && [ -n "$error" ] && [ "$error" != "null" ]; then
      echo ""
      echo "  Error (last 20 lines):"
      echo "    ${error//$'\n'/$'\n    '}"
      echo ""
      echo "  Full log: $log_file"
    fi

    echo ""
  }

  echo ""
  echo "╔══════════════════════════════════╗"
  echo "║     nix-update status           ║"
  echo "╚══════════════════════════════════╝"
  echo ""

  show_target nixos
  show_target hm

  echo "━━━ Commands ━━━"
  echo "  nix-update build <nixos|hm>                   Build an update"
  echo "  nix-update apply [--rebuild] [--switch] <target>  Apply (boot for nixos, switch for hm)"
  echo "  nix-update switch [--rebuild] <target>            Apply + switch (nixos-rebuild switch)"
  echo "  nix-update status                                Show this status"
  echo "  nix-update waybar                                Output JSON for waybar"
  echo ""
}

cmd_waybar() {
  read_status() {
    local file="$state_dir/nix-update-$1.json"
    if [ -f "$file" ]; then
      jq -r .status "$file" 2>/dev/null || echo "unknown"
    else
      echo "unknown"
    fi
  }

  read_tooltip() {
    local file="$state_dir/nix-update-$1.json"
    if [ -f "$file" ]; then
      local status timestamp diff_summary error
      status="$(jq -r .status "$file" 2>/dev/null)"
      timestamp="$(jq -r .timestamp "$file" 2>/dev/null)"
      diff_summary="$(jq -r '.diff_summary // ""' "$file" 2>/dev/null)"
      error="$(jq -r '.error // ""' "$file" 2>/dev/null)"

      local tip="$1: $status ($timestamp)"
      if [ -n "$diff_summary" ] && [ "$diff_summary" != "null" ]; then
        tip="$tip\n$diff_summary"
      fi
      if [ -n "$error" ] && [ "$error" != "null" ] && [ "$status" = "failed" ]; then
        tip="$tip\nerror: $error"
      fi
      echo "$tip"
    else
      echo "$1: no data"
    fi
  }

  nixos_status="$(read_status nixos)"
  hm_status="$(read_status hm)"

  status_icon() {
    case "$1" in
      failed)   echo "✗" ;;
      dirty)    echo "⚠" ;;
      building) echo "…" ;;
      ready)    echo "⬆" ;;
      pending)  echo "⏻" ;;
      current)  echo "✓" ;;
      *)        echo "?" ;;
    esac
  }

  nixos_icon="$(status_icon "$nixos_status")"
  hm_icon="$(status_icon "$hm_status")"
  text="❄$nixos_icon 🏠$hm_icon"

  class="current"
  for s in "$nixos_status" "$hm_status"; do
    case "$s" in
      failed)   class="failed" ;;
      dirty)    [ "$class" != "failed" ] && class="dirty" ;;
      building) [ "$class" != "failed" ] && [ "$class" != "dirty" ] && class="building" ;;
      pending)  [ "$class" != "failed" ] && [ "$class" != "dirty" ] && [ "$class" != "building" ] && class="pending" ;;
      ready)    [ "$class" != "failed" ] && [ "$class" != "dirty" ] && [ "$class" != "building" ] && class="ready" ;;
    esac
  done

  tooltip="$(read_tooltip nixos)\n$(read_tooltip hm)"
  tooltip_escaped="$(echo -e "$tooltip" | jq -Rs .)"

  echo "{\"text\": \"$text\", \"tooltip\": $tooltip_escaped, \"class\": \"$class\"}"
}

# --- main ---

usage() {
  echo "Usage: nix-update <command> [options] [target]" >&2
  echo "" >&2
  echo "Commands:" >&2
  echo "  build <nixos|hm>                            Build an update" >&2
  echo "  apply [--rebuild] [--switch] <nixos|hm|both>  Apply (boot for nixos, switch for hm)" >&2
  echo "  switch [--rebuild] <nixos|hm|both>           Apply + switch (nixos-rebuild switch)" >&2
  echo "  status                                      Show update status" >&2
  echo "  waybar                                      Output JSON for waybar" >&2
  exit 1
}

cmd="${1:-}"
shift || true

case "$cmd" in
  build)
    target="${1:?Usage: nix-update build <nixos|hm>}"
    cmd_build "$target"
    ;;
  apply)
    do_rebuild=0
    do_switch=0
    while [[ "${1:-}" == --* ]]; do
      case "$1" in
        --rebuild) do_rebuild=1; shift ;;
        --switch)  do_switch=1; shift ;;
        *) echo "Unknown flag: $1" >&2; exit 1 ;;
      esac
    done
    target="${1:?Usage: nix-update apply [--rebuild] [--switch] <nixos|hm|both>}"
    cmd_apply "$target" "$do_rebuild" "$do_switch"
    ;;
  switch)
    do_rebuild=0
    if [ "${1:-}" = "--rebuild" ]; then
      do_rebuild=1
      shift
    fi
    target="${1:?Usage: nix-update switch [--rebuild] <nixos|hm|both>}"
    cmd_switch "$target" "$do_rebuild"
    ;;
  status)
    cmd_status
    ;;
  waybar)
    cmd_waybar
    ;;
  *)
    usage
    ;;
esac
