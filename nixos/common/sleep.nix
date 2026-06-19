{ config, pkgs, lib, ... }:
{
  systemd.services."user-sleep@" = {
    description = "Stop user-level unit for user %i";

    # Ensures the service runs only when a string parameter is provided
    unitConfig = {
      ConditionNull = false;
      Before = [ "sleep.target" ];
      StopWhenUnneeded = true;
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      # Uses systemctl --machine to target the specific user's systemd manager (%i)
      ExecStart = "${pkgs.systemd}/bin/systemctl --machine=%i@ --user start --wait sleep.target";
      ExecStop = "${pkgs.systemd}/bin/systemctl --machine=%i@ --user stop --wait sleep.target";
      RequiredBy = [ "sleep.target" ];
    };
  };

  systemd.user.targets.sleep = {
    description = "User Sleep Target";
    unitConfig.StopWhenUnneeded = true;
  };

  systemd.user.services.warn-me = {
    description = "Warn me before sleep";
    unitConfig = {
      Before = [ "sleep.target" ];
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/echo 'Warning: System is going to sleep soon!'";
      WantedBy = [ "sleep.target" ];
    };
  };

  systemd.user.services.wakeup = {
    description = "Wakeup service";
    unitConfig = {
      After = [ "sleep.target" ];
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/echo 'System is waking up from sleep!'";
      WantedBy = [ "sleep.target" ];
    };
  };

}
