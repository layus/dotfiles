{ config, pkgs, lib, ... }:

{
  home.username = "layus";
  home.homeDirectory = "/home/layus";
  home.stateVersion = "21.11";

  custom.graphical = true;

  programs.helix.enable = true;

  programs.git = {
    userName = "Guillaume Maudoux";
    userEmail = "guillaume.maudoux@tweag.io";
  };

  nixpkgs.config.allowUnfree = true;
  imports = [
    ../profiles/nvim.nix
    ../profiles/helix.nix
  ];

  # Notifications for earlyoom daemon
  services.systembus-notify.enable = true;

  systemd.user.services = {
    discworld-gateway = {
      Unit = {
        Description = "SOCKS5 proxy to discworld";
        #ConditionEnvironment = [ "SSH_AUTH_SOCK" "SSH_AGENT_PID" ];
      };
      Service = {
        ExecStart = "${pkgs.openssh}/bin/ssh -D 8078 -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -CN sto-helit";
        RestartSec = "20";
        Restart = "always";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
  #systemd.user.services = {
  #  jottacloud-daemon = {
  #    Unit = {
  #      Description = "Jottacloud sync daemon";
  #    };
  #    Service = {
  #      ExecStart = "${pkgs.jotta-cli}/bin/jottad stdoutlog datadir .config/jottad";
  #      RestartSec = 300;
  #      Restart = "always";
  #    };
  #    Install = {
  #      WantedBy = [ "default.target" ];
  #    };
  #  };
  #};
}


