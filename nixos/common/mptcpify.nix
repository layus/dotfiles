{ config, lib, pkgs, ... }:

let
  cfg = config.services.mptcpify;
  mptcpify = pkgs.callPackage ../../pkgs/by-name/mp/mptcpify { };
in
{
  options.services.mptcpify = {
    enable = lib.mkEnableOption "mptcpify BPF program to transparently upgrade TCP to MPTCP";
  };

  config = lib.mkIf cfg.enable {
    systemd.services.mptcpify = {
      description = "Load mptcpify BPF program to upgrade TCP sockets to MPTCP";
      wantedBy = [ "multi-user.target" ];
      after = [ "sys-fs-bpf.mount" ];
      requires = [ "sys-fs-bpf.mount" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${mptcpify}/bin/mptcpify start";
        ExecStop = "${mptcpify}/bin/mptcpify stop";
      };
    };
  };
}
