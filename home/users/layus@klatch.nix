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

  # The way in from outside: klatch dials out to sto-helit and hands it back a
  # loopback port (3250) wired to klatch's sshd, which is what the ProxyCommand
  # under `Host klatch` in dotfiles/ssh/config connects to. Nothing needs to be
  # open on klatch's own firewall, and no port needs opening at home.
  #
  # This runs headless (layus is rarely the one logged in — the machine
  # autologins as `family`), so it authenticates with the dedicated passwordless
  # key rather than the agent, and klatch enables lingering for layus so the
  # unit is up from boot. IdentitiesOnly keeps ssh from offering agent keys
  # first and tripping MaxAuthTries.
  systemd.user.services.reverse-sto-helit = {
    Unit = {
      Description = "Reverse SSH tunnel exposing klatch's sshd on sto-helit:3250";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = builtins.concatStringsSep " " [
        "${pkgs.openssh}/bin/ssh -NT"
        "-o ServerAliveInterval=60"
        "-o ServerAliveCountMax=3"
        "-o ExitOnForwardFailure=yes"
        "-o IdentitiesOnly=yes"
        # sto-helit's authorized_keys pins permitlisten="localhost:3250", which
        # only matches if the bind address is spelled out here.
        "-i ${config.home.homeDirectory}/.ssh/misc/klatch-tunnel_ed25519"
        "-R localhost:3250:localhost:22"
        "sto-helit"
      ];
      RestartSec = "20";
      Restart = "always";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}

