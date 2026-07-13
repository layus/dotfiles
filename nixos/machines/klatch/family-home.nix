# Home-manager configuration for the `family` user, applied by nixos-rebuild
# through the home-manager NixOS module wired up in ./family.nix.
#
# It deliberately lives here and not in home/users/: flake.nix auto-discovers
# that directory as *standalone* configurations, stacked with home/modules/,
# which encode layus (git author identity, the discworld ssh hosts, sway,
# a developer package set). None of that belongs in a family account, and a
# standalone config would also have to be activated as the family user, who
# never sees a terminal. Here, `./rebuild nixos` carries it along.
{ pkgs, ... }:
{
  home.stateVersion = "26.05";

  # Apps for the family account. Anything system-wide (Steam, and whatever GNOME
  # ships) is already on their PATH from configuration.nix; this is the list of
  # extras that only this account gets.
  home.packages = with pkgs; [
    firefox
    vlc
  ];

  # The GNOME dash, left-to-right. Anything not listed is still reachable from
  # the app grid — this only decides what is one click away.
  dconf.settings."org/gnome/shell".favorite-apps = [
    "firefox.desktop"
    "steam.desktop"
    "org.gnome.Nautilus.desktop"
    "vlc.desktop"
  ];
}
