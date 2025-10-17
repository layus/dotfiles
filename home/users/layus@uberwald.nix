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

  services.lorri.enable = true;

  systemd.user.services.tpm-fido = {
    Unit.Description = "Fake usb FIDO device storing keys in TPM";
    Service = {
      ExecStart = "${pkgs.tpm-fido}/bin/tpm-fido";
      RestartSec = "20";
      Restart = "always";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

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

  systemd.user.services.timesheets-prompt = {
    Unit = {
      Description = "Prompt user for daily timesheet entry";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.timesheets-prompt}/bin/timesheets-prompt";
      # Optional: run in a graphical session if using GUI prompts
      #Environment = "DISPLAY=:0" "XAUTHORITY=%h/.Xauthority";
    };
  };
  systemd.user.timers.timesheets-prompt = {
    Unit = {
      Description = "Run timesheets prompt every day at 15:30";
    };
    Timer = {
      OnCalendar = "15:30";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
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


