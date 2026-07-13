# A stock GNOME desktop for non-technical users of klatch.
#
# GDM boots straight into GNOME as "family", with no password prompt. Logging
# out (or "Switch User") brings up the GDM greeter, where layus can pick Sway
# from the session menu in the bottom-right gear.
{ config, pkgs, lib, ... }:
{
  # GDM and GNOME run on Wayland, but still want the X stack around for
  # Xwayland and for the keymap that the greeter uses.
  services.xserver.enable = true;
  services.xserver.xkb.layout = "be";
  services.xserver.xkb.options = "eurosign:e";

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Sway is also a registered session (via programs.sway.enable), so the
  # default has to be pinned or autologin could land in the wrong one.
  services.displayManager.defaultSession = "gnome";
  services.displayManager.autoLogin = {
    enable = true;
    user = "family";
  };

  users.users.family = {
    isNormalUser = true;
    description = "Famille";

    # An empty hash means "no password", as opposed to `null`/absent which
    # means "no login". Autologin means it is never asked for at boot; this is
    # what makes the rare prompt (screen unlock, `su family`) take a bare
    # Enter. Deliberately not in wheel: system changes still ask for an admin.
    hashedPassword = "";

    extraGroups = [
      "networkmanager" # pick a wifi network from the shell menu
      "video"
      "audio"
      "input"
    ];

    # users.defaultUserShell is zsh, which greets a fresh $HOME with the
    # zsh-newuser-install wizard. Nobody here wants that.
    shell = pkgs.bash;
  };

  # PAM only honours an empty password where `nullok` is opted into. The GDM
  # greeter and the GNOME lock screen both go through gdm-password, which
  # substacks `login`, so opting `login` in covers all three (plus the VTs).
  # sshd has its own stack and does not inherit this.
  security.pam.services.login.allowNullPassword = true;

  # ...but an empty password must never be a way in over the network. This is
  # already sshd's default; klatch has an open port, so say it out loud.
  services.openssh.settings.PermitEmptyPasswords = false;

  # Don't lock the screen on idle: re-authenticating is exactly the friction
  # autologin is here to remove, and a lock screen that opens on Enter is
  # security theatre anyway.
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.desktop.screensaver]
    lock-enabled=false

    [org.gnome.desktop.session]
    idle-delay=0
  '';
}
