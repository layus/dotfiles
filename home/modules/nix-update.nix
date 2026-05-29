{ config, pkgs, lib, ... }:

let
  cfg = config.services.nix-update;

  mainScript = pkgs.stdenv.mkDerivation {
    name = "nix-update";
    src = pkgs.replaceVars ./nix-update.sh {
      flakeDir = cfg.flakeDir;
      nixLib = ./nix-lib.sh;
    };
    dontUnpack = true;
    runtimeDeps = with pkgs; [ coreutils hostname jq nix ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      install -Dm755 $src $out/bin/nix-update
      wrapProgram $out/bin/nix-update \
        --prefix PATH : ${lib.makeBinPath (with pkgs; [ coreutils hostname jq nix ])}
    '';
  };

in {

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
      home.packages = [ mainScript ];
    }

    (lib.mkIf cfg.enable {
      # NixOS updater service + timer
      systemd.user.services.nix-update-nixos = {
        Unit.Description = "Build NixOS config update in background";
        Service = {
          Type = "oneshot";
          ExecStart = "${mainScript}/bin/nix-update build nixos";
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
          ExecStart = "${mainScript}/bin/nix-update build hm";
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
