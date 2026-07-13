# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:
with lib;

let
  cfg = config.custom;
in
{

  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./family.nix
    ../../common/fonts.nix
    ../../common/sound.nix
    ../../common/bluetooth.nix
    ../../common/ssh.nix
    ../../common/epson.nix
    ../../common/brother.nix
    ../../common/mptcpify.nix
    ../../common/sleep.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.cleanTmpDir = true;
  #boot.tmpOnTmpfd = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nix.package = pkgs.nixVersions.latest;
  nix.extraOptions = ''
    extra-experimental-features = nix-command flakes ca-derivations impure-derivations configurable-impure-env auto-allocate-uids cgroups recursive-nix
    builders-use-substitutes = true
    max-substitution-jobs = 64
    extra-system-features = recursive-nix
  '';
  nix.settings.trusted-users = [ "@wheel" ]; # or just your username

  networking.hostName = "klatch"; # Define your hostname.
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false; # disable due to bug https://github.com/NixOS/nixpkgs/issues/180175

  # Set your time zone. `null` allows dynamic changes.
  time.timeZone = null;

  hardware.bluetooth.enable = true;
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.graphics.extraPackages = with pkgs; [ intel-vaapi-driver libva-vdpau-driver intel-media-driver ];


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

  programs.fish.enable = true;
  programs.zsh.enable = true;
  users.defaultUserShell = "/var/run/current-system/sw/bin/zsh";

  programs.nix-ld.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.layus = {
    isNormalUser = true;
    extraGroups = [
      "wheel" # sudo super-user
      "networkmanager" # set system-wide networks
      "docker" # start and use docker
      "wireshark" # root-less network captures
      "vboxusers" # vbox-related
      "adbusers" # Andoid debug bridge pivileges
      "input"
      "video" # brightness and leds control (brightnessctl)
      "libvirtd"
      "qemu-libvirtd"
      "tss" # access tpm (secure enclave)
      "uhid" # access fake usb device
      "ydotool" # access fake input device
    ];
    openssh.authorizedKeys.keys = builtins.attrValues {
      inherit (cfg.ssh.pubkeys)
        "ankh-morpork_ecdsa.pub"
        "klatch_ecdsa.pub"
        "uberwald_ecdsa.pub"
        ;
    };
  };

  #users.users.demo = {
  #  isNormalUser = true;
  #  extraGroups = [
  #    "wheel" "networkmanager" "input" "video"
  #  ];
  #};

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim
    rxvt-unicode-unwrapped.terminfo
    alacritty.terminfo
    android-tools

    #pkgs.linuxPackages.nvidia_x11.bin
    #cudatoolkit
    git
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

  services.fwupd.enable = true;

  services.pcscd.enable = true;

  services.upower.enable = true;

  services.earlyoom.enable = true;
  services.earlyoom.enableNotifications = true;
  services.earlyoom.extraArgs = [ "--ignore-root-user" "--sort-by-rss" "--avoid=[Ssway]" ];
  services.earlyoom.freeMemThreshold = 10;
  services.earlyoom.freeSwapThreshold = 90;
  # debugging
  services.earlyoom.enableDebugInfo = true;
  services.earlyoom.reportInterval = 1;

  services.gnome.gnome-keyring.enable = true; # fixes electron

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
  system.stateVersion = "26.05"; # Did you read the comment?

  # Login is GDM now, see ./family.nix. Sway is still offered as a session, but
  # it is started by GDM rather than by the greetd wrapper, so it no longer logs
  # to ~/.cache/sway/sway.log — use `journalctl --user -t sway` instead.

  services.mptcpify.enable = true;
}
