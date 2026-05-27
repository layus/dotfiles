{ config, pkgs, lib, ... }:

let
  cfg = config.services.nix-updater;

  flakeDir = cfg.flakeDir;

  # Pre-compute the --override-input flags as a flat shell-escaped string
  overrideFlags = lib.escapeShellArgs (
    lib.concatLists (lib.mapAttrsToList (name: url: [ "--override-input" name url ]) cfg.overrideInputs)
  );

  # Shared build script, parameterized by target (nixos or hm)
  buildScript = pkgs.writeShellApplication {
    name = "nix-updater-build";
    runtimeInputs = with pkgs; [ coreutils hostname jq nix ];
    text = ''
      set -euo pipefail

      target="''${1:?Usage: nix-updater-build <nixos|hm>}"
      host="$(hostname)"
      user="$USER"
      flake_dir="${flakeDir}"

      state_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      state_file="$state_dir/nix-updater-$target.json"
      log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/nix-updater"
      mkdir -p "$log_dir"
      log_file="$log_dir/$target.log"

      write_state() {
        local status="$1" result="''${2:-}" diff_summary="''${3:-}" error="''${4:-}"
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

      # Determine flake output attribute
      case "$target" in
        nixos)
          attr="nixosConfigurations.$host.config.system.build.toplevel"
          current="/run/current-system"
          ;;
        hm)
          attr="homeConfigurations.\"$user@$host\".activationPackage"
          current="$HOME/.local/state/nix/profiles/home-manager"
          # Also try the older path
          if [ ! -e "$current" ] && [ -e "$HOME/.local/state/home-manager/gcroots/current-home" ]; then
            current="$HOME/.local/state/home-manager/gcroots/current-home"
          fi
          ;;
        *)
          echo "Unknown target: $target" >&2
          exit 1
          ;;
      esac

      result_link="$log_dir/result-$target"
      lock_file="$log_dir/flake-lock-$target.json"

      write_state "building"

      echo "=== nix-updater build ($target) started at $(date) ===" > "$log_file"

      # Build with fresh inputs (without mutating flake.lock)
      build_flags=()
      for input in ${lib.escapeShellArgs cfg.updateInputs}; do
        build_flags+=(--update-input "$input")
      done
      # shellcheck disable=SC2086
      build_flags+=(${overrideFlags})

      if nix build \
          "$flake_dir#$attr" \
          "''${build_flags[@]}" \
          --out-link "$result_link" \
          --output-lock-file "$lock_file" \
          --log-format bar-with-logs \
          >> "$log_file" 2>&1; then

        result="$(readlink -f "$result_link")"

        # Compute diff summary
        diff_summary=""
        if [ -e "$current" ]; then
          diff_summary="$(nix store diff-closures "$current" "$result" 2>/dev/null | head -30 || true)"
        fi

        # Check if the build result is the same as current
        if [ -e "$current" ] && [ "$(readlink -f "$current")" = "$result" ]; then
          write_state "current" "$result" "" ""
          echo "Already up to date." >> "$log_file"
        else
          write_state "ready" "$result" "$diff_summary" ""
          echo "Build ready: $result" >> "$log_file"
        fi
      else
        error="$(tail -20 "$log_file")"
        write_state "failed" "" "" "$error"
        echo "Build failed." >> "$log_file"
        exit 1
      fi
    '';
  };

  # Apply script
  applyScript = pkgs.writeShellApplication {
    name = "nix-updater-apply";
    runtimeInputs = with pkgs; [ coreutils hostname jq ];
    text = ''
      set -euo pipefail

      target="''${1:?Usage: nix-updater-apply <nixos|hm|both>}"
      host="$(hostname)"
      flake_dir="${flakeDir}"

      apply_one() {
        local t="$1"
        local state_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        local state_file="$state_dir/nix-updater-$t.json"

        if [ ! -f "$state_file" ]; then
          echo "No state file for $t — nothing to apply."
          return 1
        fi

        local status
        status="$(jq -r .status "$state_file")"
        if [ "$status" != "ready" ]; then
          echo "$t: status is '$status', not 'ready'. Nothing to apply."
          return 1
        fi

        echo "=== Applying $t update ==="

        # Build override flags to match what the build used
        # shellcheck disable=SC2086
        local -a override_flags=(${overrideFlags})

        # Use the recorded lock file so the apply uses the same inputs as the build
        local recorded_lock
        recorded_lock="$(jq -r '.lock_file // ""' "$state_file")"
        if [ -n "$recorded_lock" ] && [ -f "$recorded_lock" ]; then
          override_flags+=(--reference-lock-file "$recorded_lock")
        fi

        case "$t" in
          nixos)
            echo "Running: sudo nixos-rebuild boot --flake $flake_dir#$host ''${override_flags[*]}"
            sudo nixos-rebuild boot --flake "$flake_dir#$host" "''${override_flags[@]}"
            ;;
          hm)
            echo "Running: home-manager switch --flake $flake_dir#$USER@$host ''${override_flags[*]}"
            home-manager switch --flake "$flake_dir#$USER@$host" "''${override_flags[@]}"
            ;;
        esac

        # Update state
        local result
        result="$(jq -r .result "$state_file")"
        jq --arg timestamp "$(date -Iseconds)" \
           '.status = "current" | .timestamp = $timestamp' \
           "$state_file" > "$state_file.tmp" \
           && mv "$state_file.tmp" "$state_file"

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
        *)
          echo "Usage: nix-updater-apply <nixos|hm|both>" >&2
          exit 1
          ;;
      esac
    '';
  };

  # Interactive status script (for on-click)
  statusScript = pkgs.writeShellApplication {
    name = "nix-updater-status";
    runtimeInputs = with pkgs; [ coreutils jq ];
    text = ''
      state_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/nix-updater"

      show_target() {
        local t="$1"
        local state_file="$state_dir/nix-updater-$t.json"
        local log_file="$log_dir/$t.log"

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

        if [ "$status" = "ready" ] && [ -n "$result" ]; then
          echo "  Result:    $result"
        fi

        if [ -n "$diff_summary" ] && [ "$diff_summary" != "null" ] && [ "$diff_summary" != "" ]; then
          echo ""
          echo "  Changes:"
          echo "    ''${diff_summary//$'\n'/$'\n    '}"
        fi

        if [ "$status" = "failed" ] && [ -n "$error" ] && [ "$error" != "null" ]; then
          echo ""
          echo "  Error (last 20 lines):"
          echo "    ''${error//$'\n'/$'\n    '}"
          echo ""
          echo "  Full log: $log_file"
        fi

        echo ""
      }

      echo ""
      echo "╔══════════════════════════════════╗"
      echo "║     nix-updater status           ║"
      echo "╚══════════════════════════════════╝"
      echo ""

      show_target nixos
      show_target hm

      echo "━━━ Available commands ━━━"
      echo "  nix-updater-apply nixos    Apply NixOS update (sudo nixos-rebuild boot)"
      echo "  nix-updater-apply hm       Apply home-manager update (home-manager switch)"
      echo "  nix-updater-apply both     Apply both"
      echo "  nix-updater-build nixos    Trigger a NixOS build now"
      echo "  nix-updater-build hm       Trigger a home-manager build now"
      echo ""

      exec bash
    '';
  };

  # Waybar status script
  waybarScript = pkgs.writeShellApplication {
    name = "nix-updater-waybar";
    runtimeInputs = with pkgs; [ coreutils jq ];
    text = ''
      state_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

      read_status() {
        local file="$state_dir/nix-updater-$1.json"
        if [ -f "$file" ]; then
          jq -r .status "$file" 2>/dev/null || echo "unknown"
        else
          echo "unknown"
        fi
      }

      read_tooltip() {
        local file="$state_dir/nix-updater-$1.json"
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

      # Per-status icon mapping
      status_icon() {
        case "$1" in
          failed)   echo "✗" ;;
          building) echo "…" ;;
          ready)    echo "⬆" ;;
          current)  echo "✓" ;;
          *)        echo "?" ;;
        esac
      }

      nixos_icon="$(status_icon "$nixos_status")"
      hm_icon="$(status_icon "$hm_status")"
      text="❄$nixos_icon 🏠$hm_icon"

      # Overall class for CSS styling (worst status wins)
      # Priority: failed > building > ready > current > unknown
      class="current"
      for s in "$nixos_status" "$hm_status"; do
        case "$s" in
          failed)   class="failed" ;;
          building) [ "$class" != "failed" ] && class="building" ;;
          ready)    [ "$class" != "failed" ] && [ "$class" != "building" ] && class="ready" ;;
        esac
      done

      tooltip="$(read_tooltip nixos)\n$(read_tooltip hm)"

      # Escape tooltip for JSON
      tooltip_escaped="$(echo -e "$tooltip" | jq -Rs .)"

      echo "{\"text\": \"$text\", \"tooltip\": $tooltip_escaped, \"class\": \"$class\"}"
    '';
  };

in {

  options.services.nix-updater = {
    enable = lib.mkEnableOption "background NixOS/home-manager update builder";

    flakeDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/nixpkgs";
      description = "Path to the flake directory.";
    };

    updateInputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nixpkgs" "homeManager" ];
      description = "Flake inputs to update (via --update-input) before building.";
    };

    overrideInputs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = { localConfig = "path:./local"; };
      description = "Flake inputs to override (via --override-input) on every build.";
    };

    calendar = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar expression for the update timer.";
    };
  };

  config = lib.mkIf cfg.enable {

    # NixOS updater service + timer
    systemd.user.services.nix-updater-nixos = {
      Unit.Description = "Build NixOS config update in background";
      Service = {
        Type = "oneshot";
        ExecStart = "${buildScript}/bin/nix-updater-build nixos";
        # Don't let a long build starve the system
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };

    systemd.user.timers.nix-updater-nixos = {
      Unit.Description = "Timer for background NixOS config builds";
      Timer = {
        OnCalendar = cfg.calendar;
        Persistent = true;
        RandomizedDelaySec = "30min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # Home-manager updater service + timer
    systemd.user.services.nix-updater-hm = {
      Unit.Description = "Build home-manager config update in background";
      Service = {
        Type = "oneshot";
        ExecStart = "${buildScript}/bin/nix-updater-build hm";
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };

    systemd.user.timers.nix-updater-hm = {
      Unit.Description = "Timer for background home-manager config builds";
      Timer = {
        OnCalendar = cfg.calendar;
        Persistent = true;
        RandomizedDelaySec = "30min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # Make scripts available in PATH
    home.packages = [
      buildScript
      applyScript
      statusScript
      waybarScript
    ];
  };
}
