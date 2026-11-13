# Unattended daily NixOS upgrade through nix-update.
#
# Replaces `system.autoUpgrade`: nix-update fast-forwards the checkout, bumps
# the tracked inputs in a self-contained copy of the flake, builds it, verifies
# it rebuilds from its embedded sources, and switches to it.  Unlike a plain
# `nixos-rebuild --override-input ...`, the result carries the verified git rev
# that the config-integrity activation check (see ../default.nix) requires.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.nix-update;

  nixUpdatePkg = pkgs.nix-update.override {
    flakeDir = cfg.flakeDir;
  };
in
{
  options.services.nix-update = {
    autoUpgrade = lib.mkEnableOption "daily build and switch of this system with nix-update";

    user = lib.mkOption {
      type = lib.types.str;
      default = "layus";
      description = "User owning the flake checkout; nix-update runs as this user.";
    };

    flakeDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.users.users.${cfg.user}.home}/.config/nixpkgs";
      defaultText = lib.literalExpression ''"''${config.users.users.''${cfg.user}.home}/.config/nixpkgs"'';
      description = "Path to the flake checkout.";
    };

    dates = lib.mkOption {
      type = lib.types.str;
      default = "04:40";
      description = "systemd OnCalendar expression for the upgrade timer.";
    };
  };

  config = lib.mkIf cfg.autoUpgrade {
    systemd.services.nix-update-os = {
      description = "Build and switch to the latest NixOS configuration (nix-update)";

      # Never interrupt ourselves while switching.
      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;

      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      # nix-update invokes `sudo` for the activation steps.
      path = [ "/run/wrappers" ];

      environment = {
        GIT_TERMINAL_PROMPT = "0";
        # No usable SSH key in an unattended service: fetch the (public)
        # upstream anonymously over HTTPS instead.
        GIT_CONFIG_COUNT = "1";
        GIT_CONFIG_KEY_0 = "url.https://github.com/.insteadOf";
        GIT_CONFIG_VALUE_0 = "git@github.com:";
      };

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        ExecStart = "${nixUpdatePkg}/bin/nix-update os switch --rebuild";
        Nice = 19;
        IOSchedulingClass = "idle";
      };

      startAt = cfg.dates;
    };

    systemd.timers.nix-update-os.timerConfig = {
      Persistent = true;
      RandomizedDelaySec = "30min";
    };

    # The exact commands nix-update runs through sudo when activating.
    security.sudo.extraRules = [{
      users = [ cfg.user ];
      commands = map
        (command: { inherit command; options = [ "NOPASSWD" ]; })
        [
          "${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --set /nix/store/*"
          "/nix/store/*/bin/switch-to-configuration switch"
          "/nix/store/*/bin/switch-to-configuration boot"
        ];
    }];
  };
}
