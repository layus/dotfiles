{ config, lib, pkgs, ... }:

rec {

  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_DBUS_REMOTE = "1";
    XDG_CURRENT_DESKTOP = "sway"; # https://github.com/emersion/xdg-desktop-portal-wlr/issues/20
    XDG_SESSION_TYPE = "wayland"; # https://github.com/emersion/xdg-desktop-portal-wlr/pull/11
  };

  xdg = {
    icons.enable = true;
    portal = {
      enable = true;
      # wlr covers only ScreenCast and Screenshot; gtk is the `default`
      # backend in sway-portals.conf and supplies everything else, notably
      # FileChooser (Firefox's file picker on Wayland). Not redundant.
      # xdg.portal.wlr.enable below pulls in xdg-desktop-portal-wlr itself.
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];

      # Without an explicit chooser, xdg-desktop-portal-wlr falls back to
      # probing for wofi/bemenu/fuzzel/... None are installed here (the sway
      # launcher is fzf-in-alacritty), so every screencast request died with
      # "wlroots: no output found" and Firefox got an empty capture.
      # slurp -o -r lets you click the output to share instead.
      wlr = {
        enable = true;
        settings.screencast = {
          chooser_type = "simple";
          chooser_cmd = "${pkgs.slurp}/bin/slurp -o -r -f %o";
        };
      };
    };
  };

  services.pipewire.enable = true;

}
