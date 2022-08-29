{ config, ... }:
let
  port = 51820;

in {
  # enable NAT
  networking.nat = {
    enable = true;
    externalInterface = "eno1";
    #internalInterfaces = [ "wg0" ];
    internalIPs = [ "10.100.0.0/16" ];
  };
  networking.firewall.allowedUDPPorts = [ port 53 ];

  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      ips = [ "10.100.0.1/24" ];

      # The port that Wireguard listens to. Must be accessible by the client.
      listenPort = port;

      # Path to the private key file.
      #
      # Note: The private key can also be included inline via the privateKey option,
      # but this makes the private key world-readable; thus, using privateKeyFile is
      # recommended.
      privateKeyFile = "/etc/wireguard/sto-lat";
      generatePrivateKeyFile = true;

      peers = [
        { # Guillaume @ Ankh-Morpork
          publicKey = "TLe4LS3gmSufuelXSErkO/iTj8zrMv/SgZGFXmCALwU=";
          allowedIPs = [ "10.100.0.10/32" ];
        }
        { # Guillaume @ Fairphone3
          publicKey = "LDAMmPt3aYAA2C61sZwQIIYMyCy62yZbaJkEle8mkhg=";
          allowedIPs = [ "10.100.0.11/32" ];
        }
      ];
    };
    #wg-escape-hatch = {
    #  # Determines the IP address and subnet of the server's end of the tunnel interface.
    #  ips = [ "10.100.1.1/24" ];
    #
    #  # The port that Wireguard listens to. Must be accessible by the client.
    #  listenPort = 53;
    #
    #  # Path to the private key file.
    #  #
    #  # Note: The private key can also be included inline via the privateKey option,
    #  # but this makes the private key world-readable; thus, using privateKeyFile is
    #  # recommended.
    #  privateKeyFile = "/etc/wireguard/sto-lat";
    #
    #  peers = [
    #    { # gmaudoux @ klatch
    #      publicKey = "gFMw+hTkGdwUeU1Gx47C7XwRoE0w5B51bc0ziqslP1U=";
    #      allowedIPs = [ "10.100.1.12/32" ];
    #    }
    #  ];
    #};
  };
}

