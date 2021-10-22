# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./webdav.nix
      #./dwarffs.nix
      /home/gmaudoux/downloads/dwarffs-f3997714bb9119ed0737af284a6f7a6c1dcce15d/module.nix
      ./cachix.nix
      ./epson.nix
      ./wireguard.nix
      ./graphical.nix
      ./fonts.nix
      ./sound.nix
      ./screencast.nix
      #/home/gmaudoux/projets/nixpkgs/canon-cups-capt-config-no-fhs.nix
      #/home/gmaudoux/projets/nixpkgs/canon-cups-capt-config.nix
    ];
  hardware.opengl.enable = true;
  hardware.opengl.driSupport32Bit = true;

  #hardware.brightnessctl.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.settings = {
    General = {
      #Enable = "Source,Sink,Media,Socket";
      #ControllerMode = "bredr";
    };
  };
 
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.extraModulePackages = [ config.boot.kernelPackages.sysdig ];

  # Enable dumps from kernel panics
  #boot.crashDump.enable = true; # requires kernel recompile...

  environment.sessionVariables.MOZ_ENABLE_WAYLAND = "1";

  networking.hostName = "klatch"; # Define your hostname.
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 8080 ];
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.networking.networkmanager.enable = true;
  nixpkgs.overlays = [
    # Not needed anymore ;-).
    #(import ./overlays/i3.nix)
    #(let url = "https://github.com/colemickens/nixpkgs-wayland/archive/master.tar.gz";
    #in import (builtins.fetchTarball url))
    #(import /home/gmaudoux/projets/nixpkgs-wayland)
    #(super: self: { bashInteractive = self.bashInteractive_5; })
  ];

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console.font = "lat9w-16";
  console.keyMap = "be-latin1";

  environment.variables = {
    LC_TIME = "fr_BE.UTF-8";
    LC_COLLATE = "fr_BE.UTF-8";
  };

  # Set your time zone.
  # null allows to change it dynamically later on.
  time.timeZone = null;

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  # environment.systemPackages = with pkgs; [
  #   wget
  # ];

  # List services that you want to enable:

  services.lorri.enable = true;

  services.neo4j.enable = true;

  services.blueman.enable = true;

  services.postfix = {
    enable = true;
    setSendmail = true;
  };

  #services.duplicati.enable = true;
  #services.duplicati.interface = "loopback";

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    ports = [22 3248];
    permitRootLogin = "no";
    passwordAuthentication = false;
    forwardX11 = true;
  };

  # Oops, what is this for ? Unlocking on login I suspect.
  #security.pam.services.lightdm.enableGnomeKeyring = true;
  # For skype i think...
  security.chromiumSuidSandbox.enable = true;
  # No need for this one.
  #services.accounts-daemon.enable = lib.mkForce false;

  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    #extraConf = "LogLevel debug\n";
  };

  services.avahi = {
    enable = true;
    nssmdns = true;
  };

  services.postgresql.enable = true;
  services.mongodb.enable = true;
  services.mysql = {
    enable = true;
    package = pkgs.mysql;
    # The script fails for some reason...
    #ensureDatabases = [ "github" ];
    #ensureUsers = [
    #  {
    #    name = "github";
    #    ensurePermissions = {
    #      "github.*" = "ALL PRIVILEGES";
    #    };
    #  }
    #];
  };


  ## User environment management

  #programs.nm-applet.enable = true;
  #systemd.user.services.nm-applet.serviceConfig.ExecStart = lib.mkForce ''${pkgs.networkmanagerapplet}/bin/nm-applet --indicator'';

  programs.zsh.enable = true;
  programs.ssh.startAgent = false; # Use keychain instead.
  programs.wireshark.enable = true;
  programs.adb.enable = true;

  documentation.man.enable = true;

  users.defaultUserShell = "/var/run/current-system/sw/bin/zsh";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.extraUsers.gmaudoux = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ 
      "wheel"           # sudo super-user
      "networkmanager"  # set system-wide networks
      "docker"          # start and use docker
      "wireshark"       # root-less network captures
      "vboxusers"       # ? vbox-related
      "sway"            # Start Sway
      "adbusers"        # ???
      "input" "video"   # brightness and leds control (brightnessctl)
    ];
    description = "Guillaume Maudoux";
    home = "/home/gmaudoux";
  };

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "18.03";
  system.copySystemConfiguration = true;

  nix = {
    buildCores = 0;
    trustedBinaryCaches = [ "https://hydra.nixos.org" ];
    trustedUsers = [ "root" "@wheel" "gmaudoux" ];
    useSandbox = true;
    #sandboxPaths = [ "/var/cache/ccache" ];
    extraOptions = ''
      auto-optimise-store = true
      gc-keep-derivations = true
      gc-keep-outputs = true
      #experimental-features = nix-command flakes ca-references
    '';
    #nixPath = [ "nixpkgs=/etc/nixos/nixpkgs" "nixos-config=/etc/nixos/configuration.nix" ];
    #package = pkgs.nixFlakes;

    binaryCaches = [
      "https://cache.nixos.org/"
      "https://layus.cachix.org"
    ];
    binaryCachePublicKeys = [
      "layus.cachix.org-1:DLp8StoDp5wj3P6Dm1YW4O03furWE5srX7XqHXi6rC8="
    ];
  };


  # Extra tuning
  virtualisation.docker.enable = true;

  virtualisation.virtualbox.host.enable = true;

  services.timesyncd.enable = true;

  services.pcscd.enable = true;

  services.openvpn.servers = {
    pigloo = {
      autoStart = true;
      config = "config /etc/nixos/klatch.ovpn";
    };
    pigloo-redirect = {
      autoStart = false;
      config = "config /etc/nixos/klatch-redirect.ovpn";
    };
  };

  #services.jenkins.enable = true;
  /*
  services.hydra = {
    enable = true;
    hydraURL = "http://localhost";
    notificationSender = "layus.on@gmail.com";
    buildMachinesFiles = lib.mkIf (config.nix.buildMachines == []) [];
    useSubstitutes = true;
  }; #*/

  programs.ssh.extraConfig = "UseRoaming No"; # Security issue ?

  # For laptops, but what does it do ?
  powerManagement.enable = true;

  # Remote access
  systemd.services."reverse-sto-lat" = {
    enable = true;
    #[Unit]
    description = "Reverse SSH to sto-lat";
    after = ["network.target"];
    requires = ["network.target"];
    #[Install]
    wantedBy = ["multi-user.target"];
    #[Service]
    serviceConfig = {
      ExecStart = "${pkgs.openssh}/bin/ssh -NTC -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -i /home/gmaudoux/.ssh/misc/passwordless_ecdsa -R 3250:localhost:3248 maudoux.be testconnect";
      # Restart every >2 seconds to avoid StartLimitInterval failure
      RestartSec = 3;
      Restart = "always";
      User = "gmaudoux";
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    cifs-utils
    rxvt_unicode.terminfo
    termite.terminfo
    eid-mw
    fuse

    # other compositors/window-managers for wayland
    #waybox   # An openbox clone on Wayland
    #cage     # A Wayland kiosk (runs a single app fullscreen)
    #wayfire   # 3D wayland compositor
    #wf-config # wayfire config manager
  ];
}
