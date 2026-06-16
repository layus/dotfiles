{ config, lib, pkgs, ... }:

let
  cfg = config.services.mptcpify;
in
{
  options.services.mptcpify = {
    enable = lib.mkEnableOption "mptcpify BPF program to transparently upgrade TCP to MPTCP";
  };

  config = lib.mkIf cfg.enable {
    systemd.services.mptcpify = {
      description = "Load mptcpify BPF program to upgrade TCP sockets to MPTCP";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-pre.target" ];
      before = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.mptcpify}/bin/mptcpify start";
        ExecStop = "${pkgs.mptcpify}/bin/mptcpify stop";
      };
    };
  };
}
