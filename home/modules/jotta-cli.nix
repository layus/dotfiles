{ config, pkgs, lib, ... }:

# Home-manager module for the Jottacloud Command-line Tool. Mirrors the upstream
# NixOS `services.jotta-cli` module (which is system-level and unavailable under
# home-manager): a notify user service running `jottad`.
#
# What is and isn't declarative:
#   - The daemon invocation (datadir, options) IS declarative — set here.
#   - Auth is NOT: `jotta-cli login` takes a single-use token from the website
#     and stores an encrypted device identity in the datadir. Run it once by hand.
#   - Backup folders / tunables live in jottad's internal DB, not a config file,
#     so they can't be set declaratively. Manage them with `jotta-cli` once the
#     daemon is up (e.g. `jotta-cli add ~/Documents`).

let
  cfg = config.services.jotta-cli;
in
{
  options.services.jotta-cli = {
    enable = lib.mkEnableOption "Jottacloud Command-line Tool daemon";

    package = lib.mkPackageOption pkgs "jotta-cli" { };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/jottad";
      defaultText = lib.literalExpression ''"''${config.xdg.dataHome}/jottad"'';
      description = ''
        Directory where jottad stores its data (backup database, auth, logs).
        jottad has no built-in default and is not XDG-aware, so we default to
        the XDG data location rather than the upstream module's ~/.jottad.
      '';
    };

    options = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "slow" ];
      description = ''
        Extra command-line options passed to jottad. `stdoutlog` (so the daemon
        logs to the journal) and `datadir` (from `dataDir`) are always added and
        must not be listed here.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    systemd.user.services.jottad = {
      Unit = {
        Description = "Jottacloud Command-line Tool daemon";
        Wants = [ "network-online.target" ];
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "notify";
        EnvironmentFile = "-%h/.config/jotta-cli/jotta-cli.env";
        ExecStart = "${lib.getExe' cfg.package "jottad"} ${lib.concatStringsSep " " ([ "stdoutlog" ] ++ cfg.options ++ [ "datadir" "${cfg.dataDir}/" ])}";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
