# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  cfg = config.custom;
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../common/fonts.nix
      ../../common/screencast.nix
      ../../common/sound.nix
      ../../common/bluetooth.nix
      ../../common/ssh.nix
      ../../common/epson.nix
    ];

  security.pam.loginLimits = [
    {
      domain = "*";
      item = "nofile";
      type = "soft";
      value = "unlimited";
    }
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  #boot.cleanTmpDir = true;
  #boot.tmpOnTmpfd = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # buggy panel self refresh...
  boot.kernelParams = [ "i915.enable_psr=0" ];

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  networking.hostName = "uberwald"; # Define your hostname.
  networking.networkmanager.enable = true;
  networking.wireless.enable = false;  # Enables wireless support via wpa_supplicant.

  # Set your time zone. `null` allows dynamic changes.
  time.timeZone = null;

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.wlp0s20f3.useDHCP = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  hardware.bluetooth.enable = true;
  hardware.video.hidpi.enable = true;
  hardware.opengl.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.extraPackages = with pkgs; [ vaapiIntel vaapiVdpau libvdpau-va-gl intel-media-driver ];


  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "fr_BE.UTF-8";
    LC_COLLATE = "fr_BE.UTF-8";
  };
  console = {
    keyMap = "be-latin1";
  };

  nixpkgs.config.allowUnfree = true;

  programs.sway.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  programs.zsh.enable = true;
  users.defaultUserShell = "/var/run/current-system/sw/bin/zsh";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.layus = {
    isNormalUser = true;
    extraGroups = [
      "wheel"           # sudo super-user
      "networkmanager"  # set system-wide networks
      "docker"          # start and use docker
      "wireshark"       # root-less network captures
      "vboxusers"       # vbox-related
      "adbusers"        # Andoid debug bridge pivileges
      "input" "video"   # brightness and leds control (brightnessctl)
    ];
    openssh.authorizedKeys.keys = builtins.attrValues {
      inherit (cfg.ssh.pubkeys)
        "ankh-morpork_ecdsa.pub"
        "klatch_ecdsa.pub"
        "uberwald_ecdsa.pub"
        ;
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim
    rxvt_unicode.terminfo
    termite.terminfo
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

  programs.wireshark.enable = true;
  programs.adb.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = ''${config.services.greetd.package}/bin/agreety --cmd "${config.services.greetd.settings.initial_session.command}"'';
      };
      initial_session = {
        command = "/var/run/current-system/sw/bin/zsh -lc sway";
        user = "layus";
      };
    };
  };
  systemd.services.greetd.restartIfChanged = false;
  systemd.services.greetd.stopIfChanged = false;
  systemd.services.greetd.reloadIfChanged = true;

  # services.thinkfan.enable = true; not really needed. Same as defaults.

  virtualisation.docker.enable = true;
}

