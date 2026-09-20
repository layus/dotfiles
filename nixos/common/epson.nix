{ pkgs, config, ... }:
{
  # cupsd resolves the printer's mDNS hostname (e.g. EPSON22BF97.local) both
  # itself (adding/refreshing an IPP/dnssd queue) and from the per-job `ipp`
  # backend it forks for every print (running unprivileged as the `cups`
  # user). Both paths go through glibc NSS's mdns4_minimal module, which
  # NixOS only makes available via LD_LIBRARY_PATH (system.nssModules is not
  # wired in automatically — only into the handful of units nixpkgs
  # hardcodes, e.g. dbus-broker and systemd-timesyncd). Without it, `.local`
  # lookups silently fall through to plain unicast DNS and fail with "Name
  # or service not known" / "Unable to locate printer", even though
  # avahi-browse/avahi-resolve work fine for interactive use.
  #
  # The systemd Environment= override only covers cupsd's own process, not
  # the forked backend: cupsd does NOT pass its environment down to
  # filters/backends except for a fixed safe subset, so the backend needs
  # its own `PassEnv` in cupsd.conf, or jobs get created fine but hang
  # forever failing to locate the printer.
  systemd.services.cups.serviceConfig.Environment =
    "LD_LIBRARY_PATH=${config.system.nssModules.path}";

  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    extraConf = ''
      PassEnv LD_LIBRARY_PATH
    '';
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
