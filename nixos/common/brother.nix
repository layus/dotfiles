{
  hardware.sane.brscan5 = {
    enable = true;

    netDevices.brother-scanner = {
      model = "ADS-1700W";
      # Resolved via mDNS, so it survives DHCP/network renumbering.
      nodename = "BR5CF3705DEABB.local";
    };
  };
}
