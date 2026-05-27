{ config, pkgs, lib, ... }:

let
  cfg = config.services.nix-updater;

  flakeDir = cfg.flakeDir;

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
      update_flags=()
      for input in ${lib.escapeShellArgs cfg.updateInputs}; do
        update_flags+=(--update-input "$input")
      done

      if nix build \
          "$flake_dir#$attr" \
          "''${update_flags[@]}" \
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
    runtimeInputs = with pkgs; [ coreutils git hostname jq ];
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

        # Update flake.lock with the recorded lock file before rebuilding,
        # so nixos-rebuild/home-manager switch use the matching inputs.
        local recorded_lock
        recorded_lock="$(jq -r .lock_file "$state_file")"
        if [ -n "$recorded_lock" ] && [ -f "$recorded_lock" ]; then
          echo "Updating $flake_dir/flake.lock with recorded lock file"
          cp "$recorded_lock" "$flake_dir/flake.lock"
          git -C "$flake_dir" add flake.lock
          git -C "$flake_dir" commit -m "flake.lock: update inputs (nix-updater $t)" -- flake.lock || true
        fi

        case "$t" in
          nixos)
            echo "Running: sudo nixos-rebuild boot --flake $flake_dir#$host"
            sudo nixos-rebuild boot --flake "$flake_dir#$host"
            ;;
          hm)
            echo "Running: home-manager switch --flake $flake_dir#$USER@$host"
            home-manager switch --flake "$flake_dir#$USER@$host"
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

      # Determine overall icon and class
      # Priority: failed > building > ready > current/unknown
      icon=""
      class=""

      for s in "$nixos_status" "$hm_status"; do
        case "$s" in
          failed)   icon="✗"; class="failed" ;;
          building) [ "$class" != "failed" ] && { icon="↻"; class="building"; } ;;
          ready)    [ "$class" != "failed" ] && [ "$class" != "building" ] && { icon="⬆"; class="ready"; } ;;
          current)  [ -z "$class" ] && { icon="✓"; class="current"; } ;;
          *)        [ -z "$class" ] && { icon="?"; class="unknown"; } ;;
        esac
      done

      # Count ready updates
      ready_count=0
      [ "$nixos_status" = "ready" ] && ready_count=$((ready_count + 1))
      [ "$hm_status" = "ready" ] && ready_count=$((ready_count + 1))

      if [ "$ready_count" -gt 0 ]; then
        text="$icon $ready_count"
      else
        text="$icon"
      fi

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
      waybarScript
    ];
  };
}
