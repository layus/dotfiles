# WireGuard link to sto-helit's wg0 (10.100.0.0/24, see ../sto-helit/wireguard.nix).
#
# Only the VPN subnet is routed through the tunnel; regular traffic is
# unaffected.  Used to reach services that sto-helit exposes on wg0 only
# (e.g. the ZNC bouncer at 10.100.0.1).
#
# The private key is not managed by Nix: install it once with
#   sudo install -Dm600 <key> /etc/wireguard/uberwald.key
# Its public key is listed as a peer on sto-helit.
{ ... }:

{
  networking.wireguard.interfaces.wg-sto-helit = {
    ips = [ "10.100.0.12/24" ];
    privateKeyFile = "/etc/wireguard/uberwald.key";

    peers = [
      {
        # sto-helit
        publicKey = "P1KQPWQHZPRMtDMQmAWGy/wzfPqOOBd3YsiwoFu2GGk=";
        endpoint = "sto-helit.maudoux.be:51820";
        allowedIPs = [ "10.100.0.0/24" ];
        # uberwald is a laptop behind NAT: keep the mapping open so sto-helit
        # can reach us (and so roaming between networks recovers quickly).
        persistentKeepalive = 25;
      }
    ];
  };
}
