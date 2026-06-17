{ lib, stdenvNoCC, llvmPackages, libbpf, bpftools, writeShellApplication }:

let
  bpfObject = stdenvNoCC.mkDerivation {
    pname = "mptcpify-bpf";
    version = "0.1.0";

    src = ./mptcpify.c;
    dontUnpack = true;

    nativeBuildInputs = [ llvmPackages.clang-unwrapped ];

    buildPhase = ''
      clang -target bpf -O2 -g \
        -I${libbpf}/include \
        -c $src -o mptcpify.bpf.o
    '';

    installPhase = ''
      install -Dm644 mptcpify.bpf.o $out/lib/bpf/mptcpify.bpf.o
    '';
  };
in
writeShellApplication {
  name = "mptcpify";
  runtimeInputs = [ bpftools ];
  text = ''
    if [ "$(id -u)" -ne 0 ]; then
      echo "Error: mptcpify must be run as root" >&2
      exit 1
    fi

    BPF_OBJ="${bpfObject}/lib/bpf/mptcpify.bpf.o"
    PIN_PATH="/sys/fs/bpf/mptcpify"

    case "''${1:-}" in
      start)
        echo "Loading mptcpify BPF program..."
        bpftool prog load "$BPF_OBJ" "$PIN_PATH" autoattach
        echo "mptcpify active: TCP sockets will be upgraded to MPTCP"
        ;;
      stop)
        echo "Removing mptcpify BPF program..."
        rm -f "$PIN_PATH"
        echo "mptcpify removed"
        ;;
      status)
        if [ -e "$PIN_PATH" ]; then
          echo "mptcpify is active"
          bpftool link show pinned "$PIN_PATH"
        else
          echo "mptcpify is not active"
        fi
        ;;
      *)
        echo "Usage: mptcpify {start|stop|status}"
        exit 1
        ;;
    esac
  '';
}
