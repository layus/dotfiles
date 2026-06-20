{ config, pkgs, lib, ... }:
let
  normalUsers = lib.attrNames
    (lib.filterAttrs
      (name: user: user.isNormalUser)
      config.users.users
    );
in
{

  # Use symlinks to instantiate user-sleep@.service for each normal user,
  # mimicking what systemd does when resolving template instances.
  # sleep.target.requires/user-sleep@<name>.service -> ../user-sleep@.service
  systemd.packages = [
    (pkgs.runCommand "user-sleep-instances"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
      } ''
      mkdir -p $out/etc/systemd/system/sleep.target.requires
      ${lib.concatMapStrings (name: ''
        ln -s ../user-sleep@.service $out/etc/systemd/system/sleep.target.requires/user-sleep@${name}.service
      '') normalUsers}
    '')
  ];

  systemd.services."user-sleep@" = {
    description = "Stop user-level unit for user %i";
    unitConfig = {
      Before = [ "sleep.target" ];
      StopWhenUnneeded = true;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      ExecStart = "${pkgs.systemd}/bin/systemctl --machine=%i@.host --user start sleep.target";
      ExecStop = "${pkgs.systemd}/bin/systemctl --machine=%i@.host --user stop sleep.target";
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
    };
    wantedBy = [ "sleep.target" ];
  };

  systemd.user.services.wakeup = {
    description = "Wakeup service";
    unitConfig = {
      After = [ "sleep.target" ];
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/echo 'System is waking up from sleep!'";
    };
    wantedBy = [ "sleep.target" ];
  };

}
