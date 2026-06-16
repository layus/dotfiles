{ config, pkgs, lib, ... }:

let
  cfg = config.services.nix-update;

  nixUpdatePkg = pkgs.nix-update.override {
    flakeDir = cfg.flakeDir;
  };

  hasNixos = builtins.elem "os" cfg.targets;
  hasHm = builtins.elem "hm" cfg.targets;
  motdScope =
    if hasNixos && hasHm then "both"
    else if hasNixos then "os"
    else "hm";

in
{

  options.services.nix-update = {
    targets = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [ "os" "hm" ]);
      default = [ "hm" ];
      description = "Which targets to build/monitor. Set to [ \"os\" \"hm\" ] on NixOS machines.";
    };

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

    (lib.mkIf (cfg.targets != [ ]) {
      programs.zsh.loginExtra = ''
        # nix-update MOTD
        uptime 2>/dev/null
        ${nixUpdatePkg}/bin/nix-update ${motdScope} motd 2>/dev/null
      '';
      programs.bash.profileExtra = ''
        # nix-update MOTD
        uptime 2>/dev/null
        ${nixUpdatePkg}/bin/nix-update ${motdScope} motd 2>/dev/null
      '';
    })

    (lib.mkIf hasNixos {
      # NixOS updater service + timer
      systemd.user.services.nix-update-os = {
        Unit.Description = "Build NixOS config update in background";
        Service = {
          Type = "oneshot";
          ExecStart = "${nixUpdatePkg}/bin/nix-update os build";
          Nice = 19;
          IOSchedulingClass = "idle";
        };
      };

      systemd.user.timers.nix-update-os = {
        Unit.Description = "Timer for background NixOS config builds";
        Timer = {
          OnCalendar = cfg.calendar;
          Persistent = true;
          RandomizedDelaySec = "30min";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    })

    (lib.mkIf hasHm {
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
