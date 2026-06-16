{ config, lib, pkgs, ... }:

let
  cfg = config.services.mptcpify;

  bpfObject = pkgs.stdenvNoCC.mkDerivation {
    pname = "mptcpify-bpf";
    version = "0.1.0";

    src = ../../home/pkgs/by-name/mp/mptcpify/mptcpify.c;
    dontUnpack = true;

    nativeBuildInputs = [ pkgs.llvmPackages.clang-unwrapped ];

    buildPhase = ''
      clang -target bpf -O2 -g \
        -I${pkgs.libbpf}/include \
        -c $src -o mptcpify.bpf.o
    '';

    installPhase = ''
      install -Dm644 mptcpify.bpf.o $out/lib/bpf/mptcpify.bpf.o
    '';
  };
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
        ExecStart = "${pkgs.bpftools}/bin/bpftool prog load ${bpfObject}/lib/bpf/mptcpify.bpf.o /sys/fs/bpf/mptcpify autoattach";
        ExecStop = "${pkgs.coreutils}/bin/rm -f /sys/fs/bpf/mptcpify";
      };
    };
  };
}
