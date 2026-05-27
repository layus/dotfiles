{ config, pkgs, lib, ... }:

let
  cfg = config.services.nix-updater;

  # Pre-compute substitution values for the bash script
  updateInputFlags = lib.escapeShellArgs cfg.updateInputs;
  overrideInputFlags = lib.escapeShellArgs (
    lib.concatLists (lib.mapAttrsToList (name: url: [ "--override-input" name url ]) cfg.overrideInputs)
  );

  mainScript = pkgs.stdenv.mkDerivation {
    name = "nix-updater";
    src = pkgs.replaceVars ./nix-updater.sh {
      flakeDir = cfg.flakeDir;
      inherit updateInputFlags overrideInputFlags;
    };
    dontUnpack = true;
    runtimeDeps = with pkgs; [ coreutils hostname jq nix ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      install -Dm755 $src $out/bin/nix-updater
      wrapProgram $out/bin/nix-updater \
        --prefix PATH : ${lib.makeBinPath (with pkgs; [ coreutils hostname jq nix ])}
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
        ExecStart = "${mainScript}/bin/nix-updater build nixos";
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
        ExecStart = "${mainScript}/bin/nix-updater build hm";
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
      mainScript
    ];
  };
}
