{ pkgs, config, ... }:
{
  # cupsd resolves the printer's mDNS hostname (e.g. EPSON22BF97.local) itself
  # when adding/refreshing an IPP/dnssd queue. That resolution goes through
  # glibc NSS's mdns4_minimal module, which NixOS makes available only via
  # LD_LIBRARY_PATH (system.nssModules is not wired into every service
  # automatically — only into the handful of units nixpkgs hardcodes, e.g.
  # dbus-broker and systemd-timesyncd). Without this override cupsd's .local
  # lookups silently fall through to plain unicast DNS and fail with
  # "Name or service not known", breaking auto-discovered queue setup even
  # though avahi-browse/avahi-resolve work fine for interactive use.
  systemd.services.cups.serviceConfig.Environment =
    "LD_LIBRARY_PATH=${config.system.nssModules.path}";

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
    #
    # Note `browsing` alone is not enough: it only writes `Browsing No` into
    # cupsd.conf. The daemon itself is gated on `browsed.enable`, which
    # defaults to true.
    browsed.enable = false;
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
