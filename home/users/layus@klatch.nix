{ config, pkgs, lib, ... }:

{
  home.username = "layus";
  home.stateVersion = "26.05";

  custom.graphical = true;

  services.nix-update.targets = [ "os" "hm" ];

  programs.git = {
    settings.user.name = "Guillaume Maudoux";
    settings.user.email = "guillaume.maudoux@gmail.com";
  };

  nixpkgs.config.allowUnfree = true;

  services.systembus-notify.enable = true;

  systemd.user.services.discworld-gateway = {
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
}

