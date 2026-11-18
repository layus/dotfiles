# ZNC IRC bouncer, reachable only over the WireGuard bridge (wg0, see
# ./wireguard.nix).  The firewall is NOT opened on the public interface.
#
# Clients connect to 10.100.0.1:6667 with server password
# "layus/hackint:<password>".  No TLS on the listener: the WireGuard tunnel
# already encrypts and authenticates the link.
#
# The configuration is immutable (rebuilt from Nix on every start), so
# declare channels below rather than relying on /join persisting.
#
# Credentials stay out of Nix: module data (users/layus/networks/*/moddata)
# is not part of znc.conf and survives restarts.  Set them once at runtime:
#   /msg *sasl Set <account> <password>
#   /msg *sasl Mechanism PLAIN
# (or CertFP: put a PEM at .../networks/hackint/moddata/cert/user.pem and
# load the `cert` module instead of `sasl`).
let
  wgAddress = "10.100.0.1";
  port = 6667;
in
{
  services.znc = {
    enable = true;
    mutable = false; # Overwrite configuration set by ZNC from the web and chat interfaces.
    useLegacyConfig = false; # Turn off services.znc.confOptions and their defaults.
    openFirewall = false; # Only reachable through wg0, opened below.

    config = {
      LoadModule = [ "adminlog" ]; # Write access logs to ~znc/moddata/adminlog/znc.log.

      Listener.l = {
        Host = wgAddress;
        Port = port;
        IPv4 = true;
        IPv6 = false;
        SSL = false;
        AllowWeb = false;
      };

      User.layus = {
        Admin = true;
        Nick = "layus";
        AltNick = "layus_";
        # Generated with `znc --makepass`-compatible sha256(password + salt).
        Pass.password = {
          Method = "sha256";
          Hash = "40dc8e2aeff3cf539135fdd4a7d1dc01486cc98622c5cf916264479adb38f1a3";
          Salt = "uLcTm7C6lvcbPWVln2ED";
        };

        Network.hackint = {
          Server = "irc.eu.hackint.org +6697";
          LoadModule = [ "sasl" ];
          JoinDelay = 2; # Let SASL/NickServ finish before joining channels.
          Chan = { };
        };
      };
    };
  };

  networking.firewall.interfaces.wg0.allowedTCPPorts = [ port ];

  # The listener binds the wg0 address, which only exists once the tunnel is up.
  systemd.services.znc = {
    wants = [ "wireguard-wg0.service" ];
    after = [ "wireguard-wg0.service" ];
  };
}
