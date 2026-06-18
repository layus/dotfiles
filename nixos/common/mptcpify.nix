{ config, lib, pkgs, ... }:

let
  cfg = config.services.mptcpify;
in
{
  options.services.mptcpify = {
    enable = lib.mkEnableOption "mptcpify BPF program to transparently upgrade TCP to MPTCP";

    multihoming = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable per-source routing rules for MPTCP multihoming.";
    };
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

    #    # Per-source routing for MPTCP multihoming.
    #    # Each interface gets its own routing table so that reply packets
    #    # (e.g. SYN-ACK for MP_JOIN) are routed back through the correct interface.
    #    networking.networkmanager.dispatcherScripts = lib.mkIf cfg.multihoming [
    #      {
    #        type = "basic";
    #        source = pkgs.writeShellScript "mptcp-multihoming" ''
    #          IFACE="$1"
    #          ACTION="$2"
    #
    #          # Only act on interfaces that get an IPv4 address
    #          [[ "$ACTION" != "up" && "$ACTION" != "down" ]] && exit 0
    #
    #          # Assign a stable table number from the interface name
    #          TABLE=$(( 0x$(echo -n "$IFACE" | md5sum | head -c 4) % 1000 + 100 ))
    #
    #          case "$ACTION" in
    #            up)
    #              IP4_ADDR="$IP4_ADDRESS_0"
    #              IP4_ADDR="''${IP4_ADDR%%/*}"
    #              IP4_GW="$IP4_GATEWAY"
    #
    #              [ -z "$IP4_ADDR" ] && exit 0
    #
    #              # Get the subnet from ip addr
    #              SUBNET=$(${pkgs.iproute2}/bin/ip -4 addr show dev "$IFACE" | ${pkgs.gawk}/bin/awk '/inet / {print $2}')
    #
    #              # Add per-interface routing table
    #              ${pkgs.iproute2}/bin/ip route replace $SUBNET dev "$IFACE" src "$IP4_ADDR" table $TABLE
    #              if [ -n "$IP4_GW" ]; then
    #                ${pkgs.iproute2}/bin/ip route replace default via "$IP4_GW" dev "$IFACE" table $TABLE
    #              fi
    #
    #              # Add source-based rule (idempotent via prio)
    #              PRIO=$(( TABLE + 100 ))
    #              ${pkgs.iproute2}/bin/ip rule del prio $PRIO 2>/dev/null || true
    #              ${pkgs.iproute2}/bin/ip rule add from "$IP4_ADDR" table $TABLE prio $PRIO
    #              ;;
    #            down)
    #              # Clean up rules pointing to this table
    #              ${pkgs.iproute2}/bin/ip rule show | ${pkgs.gnugrep}/bin/grep "lookup $TABLE" | while read -r line; do
    #                PRIO=$(echo "$line" | ${pkgs.gnugrep}/bin/grep -oP '^\d+')
    #                ${pkgs.iproute2}/bin/ip rule del prio "$PRIO" 2>/dev/null || true
    #              done
    #              ${pkgs.iproute2}/bin/ip route flush table $TABLE 2>/dev/null || true
    #              ;;
    #          esac
    #        '';
    #      }
    #    ];
    #
    #    boot.kernel.sysctl = lib.mkIf cfg.multihoming {
    #      # Allow MPTCP joins on the initial address+port
    #      "net.mptcp.allow_join_initial_addr_port" = 1;
    #      # Loose reverse path filtering (needed for asymmetric routing)
    #      "net.ipv4.conf.all.rp_filter" = 0;
    #      "net.ipv4.conf.default.rp_filter" = 2;
    #    };
    #
    #    # Conntrack does not understand MPTCP subflows (MP_JOIN) and marks them
    #    # INVALID, which the NixOS firewall then drops.  Accept both INVALID and
    #    # UNTRACKED TCP packets so that MP_JOIN handshakes complete.  The TCP
    #    # stack will RST truly invalid connections on its own.
    #    networking.firewall.extraCommands = lib.mkIf cfg.multihoming ''
    #      iptables -I nixos-fw 3 -p tcp -m conntrack --ctstate INVALID,UNTRACKED -j nixos-fw-accept
    #    '';
  };
}
