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

  # Keep a *permanent* driverless queue for the ET-2850. Without one, the GTK
  # print dialog only sees the printer through DNS-SD and asks cupsd for a
  # temporary queue on the fly (CUPS-Create-Local-Printer). GTK then fetches
  # the queue's PPD immediately, but cupsd builds it asynchronously (~7s), so
  # GTK gets a 404, falls back to the half-built queue's attributes and shows
  # generic options (no paper sizes) until the app is restarted. A permanent
  # queue already has its PPD, so there is no race.
  #
  # hardware.printers.ensurePrinters is not used here because it re-runs
  # `lpadmin -m everywhere` on every boot. That needs the printer to be
  # reachable at that moment, so the unit fails whenever we are away from
  # home. This one only acts when the queue is missing (or only temporary,
  # meaning it is absent from printers.conf) and skips quietly if the
  # printer cannot be reached.
  systemd.services.epson-printer-queue =
    let
      name = "EPSON_ET_2850_Series";
      uri = "ipp://EPSON22BF97.local:631/ipp/print";
    in
    {
      description = "Ensure permanent CUPS queue for the Epson ET-2850";
      wantedBy = [ "multi-user.target" ];
      wants = [ "cups.service" "network-online.target" ];
      after = [ "cups.service" "avahi-daemon.service" "network-online.target" ];
      environment.LD_LIBRARY_PATH = config.system.nssModules.path;
      serviceConfig.Type = "oneshot";
      script = ''
        if grep -qx '<\(Default\)\?Printer ${name}>' /etc/cups/printers.conf 2>/dev/null; then
          exit 0
        fi
        if ${pkgs.cups}/bin/lpadmin -p ${name} -v ${uri} -m everywhere -E; then
          ${pkgs.cups}/bin/lpadmin -d ${name}
        else
          echo "${uri} unreachable; leaving queue setup for next start" >&2
        fi
      '';
    };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    settings.publish = {
      disable-publishing = false;
      disable-user-service-publishing = false;
      publish-addresses = true;
    };
  };

  hardware.sane = {
    enable = true;
    extraBackends = [
      #pkgs.epson-escpr
      pkgs.epson-escpr2
    ];
  };
}
