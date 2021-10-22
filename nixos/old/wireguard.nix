{ config, pkgs, lib, ... }:
with { inherit (config.boot) kernelPackages; };
{
  boot.extraModulePackages = lib.optional (lib.versionOlder kernelPackages.kernel.version "5.6") kernelPackages.wireguard;
  environment.systemPackages = [ pkgs.wireguard-tools ];

#  # Enable Wireguard
#  networking.wireguard.interfaces = {
#    # "wg0" is the network interface name. You can name the interface arbitrarily.
#    wg0 = {
#      # Determines the IP address and subnet of the client's end of the tunnel interface.
#      ips = [ "10.100.1.12/24" ];
#
#      # Path to the private key file.
#      #
#      # Note: The private key can also be included inline via the privateKey option,
#      # but this makes the private key world-readable; thus, using privateKeyFile is
#      # recommended.
#      privateKeyFile = "/etc/nixos/klatch.wg";
#
#      peers = [
#        # For a client configuration, one peer entry for the server will suffice.
#        {
#          # Public key of the server (not a file path).
#          publicKey = "GXsYLSON3MZF/iSQfSTRLz3vS10GO47mICpSE7VW7E0=";
#
#          # Forward all the traffic via VPN.
#          allowedIPs = [ "0.0.0.0/0" ];
#          # Or forward only particular subnets
#          #allowedIPs = [ "10.100.0.1" "91.108.12.0/22" ];
#
#          # Set this to the server IP and port.
#          endpoint = "37.59.63.147:53";
#
#          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
#          persistentKeepalive = 25;
#        }
#      ];
#    };
#  };
}
