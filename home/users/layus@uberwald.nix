{ config, pkgs, lib, ... }:

{
  home.username = "layus";
  home.stateVersion = "21.11";

  custom.graphical = true;

  services.nix-update.targets = [ "os" "hm" ];

  programs.helix.enable = true;

  programs.git = {
    settings.user.name = "Guillaume Maudoux";
    settings.user.email = "guillaume.maudoux@tweag.io";
  };

  services.kdeconnect = {
    enable = true;
    #package = pkgs.kdePackages.kdeconnect-kde;
    indicator = true;
  };

  nixpkgs.config.allowUnfree = true;
  imports = [
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

      # The start limiter counts every start over a sliding window, including
      # timer- and hand-triggered ones, not just Restart= ones. The retries
      # below are 10 minutes apart so they cannot trip the default (5 per 10s)
      # on their own, but a Persistent=true catch-up firing on resume alongside
      # a pending restart could. Tripping it fails the unit outright, which
      # would silently drop the prompt for the day.
      StartLimitIntervalSec = 0;
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.timesheets-prompt}/bin/timesheets-prompt";
      # Optional: run in a graphical session if using GUI prompts
      #Environment = "DISPLAY=:0" "XAUTHORITY=%h/.Xauthority";

      # The prompt cannot always take the session lock: another locker may hold
      # the screen, or (after resuming from sleep) the compositor may never
      # answer the lock request at all. The latter wedges a process-global in
      # gtk4-layer-shell that no API can clear, so the only way to retry is a
      # brand new process -- which is what this restart loop provides.
      #
      # The script exits 75 (EX_TEMPFAIL) to ask for another attempt and 0 once
      # it is done, either because the timesheet was filed or because the
      # deadline below passed.
      #
      # Note 75 must NOT be added to SuccessExitStatus=: that would make it a
      # success, and Restart=on-failure does not fire on success, so the unit
      # would quietly stop after the first attempt. Each retry is therefore
      # recorded as a failed start in the journal, which is noisy but honest --
      # the prompt really did fail to appear.
      #
      # RestartPreventExitStatus= narrows on-failure back down to *only* 75.
      # Without it any nonzero exit restarts, so a deterministic crash (a broken
      # GI typelib, no Wayland display) would relaunch every 10 minutes forever,
      # never reaching the code that checks the deadline. Those exits should
      # leave the unit visibly failed instead.
      Restart = "on-failure";
      RestartForceExitStatus = "75";
      RestartPreventExitStatus = "1 2 70 71 78 SIGABRT SIGSEGV SIGTRAP";
      RestartSec = "10min";

      # Bound the whole affair in *wall-clock* time rather than by a restart
      # count: the laptop suspends for hours at a time, so a count says nothing
      # about how long the prompt has been nagging. The script stamps a deadline
      # into $XDG_RUNTIME_DIR on its first run, carries it across restarts, and
      # exits 0 once it passes -- 20h30, deliberately shorter than the 24h
      # between firings, so one day's retry chain always ends before the next
      # day's activation arrives. Nothing in systemd distinguishes a fresh
      # activation from an automatic restart, so that margin is what keeps the
      # two apart.
      #
      # That has to live in the script: systemd has no "stop restarting after a
      # wall-clock instant" knob. StartLimitIntervalSec= is a rate limit (N
      # starts per window) that a long suspend would not trip, and RuntimeMaxSec=
      # is documented to have no effect on Type=oneshot.
      #
      # Deliberately no TimeoutStartSec: a oneshot unit stays in "activating"
      # for as long as the process lives, so any value here would also cap how
      # long the prompt may sit on screen waiting to be answered. The wedged
      # case is instead caught inside the script, by the 30s timeout on the
      # lock being confirmed.
    };
  };
  systemd.user.timers.timesheets-prompt = {
    Unit = {
      Description = "Run timesheets prompt every day at 15:30";
    };
    Timer = {
      OnCalendar = "Mon..Fri *-*-* 15:30";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # Jottacloud backup daemon (see home/modules/jotta-cli.nix). Enabled only here,
  # on uberwald. Datadir defaults to the XDG location ~/.local/share/jottad.
  # Log in and manage backups by hand once the daemon is up:
  #   jotta-cli login && jotta-cli add ~/Documents
  services.jotta-cli.enable = true;
}


