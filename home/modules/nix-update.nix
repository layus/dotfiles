{ config, pkgs, lib, ... }:

let
  cfg = config.services.nix-update;

  nixUpdatePkg = pkgs.callPackage ../pkgs/by-name/ni/nix-update {
    flakeDir = cfg.flakeDir;
  };

in
{

  options.services.nix-update = {
    enable = lib.mkEnableOption "background NixOS/home-manager update builder (nix-update)";

    flakeDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/nixpkgs";
      description = "Path to the flake directory.";
    };

    calendar = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar expression for the update timer.";
    };
  };

  config = lib.mkMerge [
    {
      # Always make the nix-update command available
      home.packages = [ nixUpdatePkg ];
    }

    (lib.mkIf cfg.enable {
      # NixOS updater service + timer
      systemd.user.services.nix-update-nixos = {
        Unit.Description = "Build NixOS config update in background";
        Service = {
          Type = "oneshot";
          ExecStart = "${nixUpdatePkg}/bin/nix-update nixos build";
          # Don't let a long build starve the system
          Nice = 19;
          IOSchedulingClass = "idle";
        };
      };

      systemd.user.timers.nix-update-nixos = {
        Unit.Description = "Timer for background NixOS config builds";
        Timer = {
          OnCalendar = cfg.calendar;
          Persistent = true;
          RandomizedDelaySec = "30min";
        };
        Install.WantedBy = [ "timers.target" ];
      };

      # Home-manager updater service + timer
      systemd.user.services.nix-update-hm = {
        Unit.Description = "Build home-manager config update in background";
        Service = {
          Type = "oneshot";
          ExecStart = "${nixUpdatePkg}/bin/nix-update hm build";
          Nice = 19;
          IOSchedulingClass = "idle";
        };
      };

      systemd.user.timers.nix-update-hm = {
        Unit.Description = "Timer for background home-manager config builds";
        Timer = {
          OnCalendar = cfg.calendar;
          Persistent = true;
          RandomizedDelaySec = "30min";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    })
  ];
}
