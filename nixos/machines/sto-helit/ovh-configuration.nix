{ pkgs, config, ... }:

{
  networking = {
    hostName = "sto-helit";
    domain = "maudoux.be";

    interfaces.eno1 = {
      #ip4 = [ { address = "37.59.63.147"; prefixLength = 24; } ];
      ipv6.addresses = [ { address = "2001:41d0:8:e79d::1"; prefixLength = 64; } ];
      ipv6.routes = [ { address = "2001:41d0:8:e7ff:ff:ff:ff:ff"; prefixLength = 128; } ];
    };
    #interfaces.enp0s25 = {
    #  #ip4 = [ { address = "37.59.63.147"; prefixLength = 24; } ];
    #  ipv6.addresses = [ { address = "2001:41d0:8:e79d::1"; prefixLength = 64; } ];
    #};

    #defaultGateway = "37.59.63.254"; # auto
    defaultGateway6 = "2001:41d0:8:e7ff:ff:ff:ff:ff";

    nameservers = [ "213.186.33.99" "2001:41d0:3:163::1" ];
  };
}
