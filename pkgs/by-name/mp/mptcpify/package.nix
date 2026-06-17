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
    PIN_DIR="/sys/fs/bpf/mptcpify"

    case "''${1:-}" in
      start)
        echo "Loading mptcpify BPF program..."
        mkdir -p "$PIN_DIR"
        bpftool prog loadall "$BPF_OBJ" "$PIN_DIR" autoattach
        echo "mptcpify active: TCP sockets will be upgraded to MPTCP"
        ;;
      stop)
        echo "Removing mptcpify BPF program..."
        rm -rf "$PIN_DIR"
        echo "mptcpify removed"
        ;;
      status)
        if [ -d "$PIN_DIR" ]; then
          echo "mptcpify is active"
          bpftool prog show pinned "$PIN_DIR/mptcpify" 2>/dev/null || true
          for f in "$PIN_DIR"/*link*; do
            [ -e "$f" ] && bpftool link show pinned "$f" 2>/dev/null
          done
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
