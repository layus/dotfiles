{ pkgs, ... }:
{
  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = [
      #pkgs.epson-escpr
      pkgs.epson-escpr2
    ];
    # The ET-2850 is IPP Everywhere / Mopria capable, so it is driven over a
    # plain ipp:// queue (`lpadmin -m everywhere`). cups-browsed is deprecated
    # upstream and only got in the way here: it kept recreating an
    # implicitclass:// queue whose backend died with NO_DEST_FOUND, shadowing
    # the working queue in the GNOME print dialog.
    browsing = false;
    defaultShared = false;
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
    publish.userServices = true;
  };

  hardware.sane = {
    enable = true;
    extraBackends = [
      #pkgs.epson-escpr
      pkgs.epson-escpr2
    ];
  };
}
