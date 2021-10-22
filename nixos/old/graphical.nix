{ config, lib, pkgs, ... }:

{
  #Sway

  imports = [ ./screencast.nix ];

  programs.sway = {
    enable = true;
    extraSessionCommands = ''
      export XKB_DEFAULT_LAYOUT=be
    '';

    # TODO: How much of this needs to be installed as root ?
    extraPackages = with pkgs; [
      xwayland
      swaybg   # required by sway for controlling desktop wallpaper
      swayidle # used for controlling idle timeouts and triggers (screen locking, etc)
      swaylock # used for locking Wayland sessions

      waybar        # polybar-alike
      #i3status-rust # simpler bar written in Rust

      gebaar-libinput  # libinput gestures utility
      #glpaper          # GL shaders as wallpaper
      grim             # screen image capture
      kanshi           # dynamic display configuration helper
      mako             # notification daemon
      #oguri            # animated background utility
      #redshift-wayland # patched to work with wayland gamma protocol
      slurp            # screen area selection tool
      waypipe          # network transparency for Wayland
      #wf-recorder      # wayland screenrecorder
      wl-clipboard     # clipboard CLI utilities
      #wtype            # xdotool, but for wayland
      wdisplays

      # TODO: more steps required to use this?
      #xdg-desktop-portal-wlr # xdg-desktop-portal backend for wlroots
    ];
  };


  # X11
  # Keep this around in case of emergency.
  # (sway does not support screen replication for example)

  systemd.defaultUnit = "multi-user.target";
  #systemd.services.display-manager.wantedBy = lib.mkForce [];
  services.xserver = {
    enable = true;
    autorun = false;
    exportConfiguration = true;
  
    videoDrivers = [ "intel" ];
    #deviceSection = ''
    #  Option "DRI" "2"
    #  Option "TearFree" "true"
    #'';
    # Keyboard
    layout = "be";
    xkbOptions = "eurosign:e";
    # Touchpad
    #multitouch.invertScroll = false;
    libinput.touchpad.naturalScrolling = false;
  
    # Graphical environemnts
    desktopManager = {
      gnome.enable = true;
      #xfce.enable = true;
      xterm.enable = false;
    };
    displayManager = {
      #lightdm.enable = true;
      gdm.enable = true;
      defaultSession = "none+i3";
    };
    windowManager = {
      i3.enable = true;
    };
  };

}
