## Config for sto-lat.
{ config, pkgs, lib, nixpkgs, ... }:
{

  ## Hardware

  imports = [
    (nixpkgs + "/nixos/modules/profiles/headless.nix")
    (nixpkgs + "/nixos/modules/installer/scan/not-detected.nix")
    #/home/layus/projects/inginious.nix
    ./lighttpd.nix
    ./wireguard.nix
    ./ovh-configuration.nix
    ./hardware-configuration.nix
    #./hardware-configuration.nix
  ];

  #boot.initrd.availableKernelModules = [ ];
  #boot.kernelModules = [ ];
  #boot.extraModulePackages = [ ];
  #boot.kernelPackages = pkgs.linuxPackages_mptcp;
  # ssh setup
  boot.initrd.network.enable = true;
  boot.initrd.network.ssh = {
    enable = true;
    port = 22;
    authorizedKeys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAjd/cnsdiyS0k3ckRO8e8bTPd2amazA8vLT2WpRfHTHyastB7JYO1yDabICq+fgpkSXUgGRjQWMhKRHEFy5Ffc= layus@ankh-morpork"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEFMsq6kKxh2so5Jr+kzHmVNfg80aXIRYfFt3k6B2osiEJH7ibnZx51BTkFd42Ld6FifWb3WjjoyNYeAnGzruvg= gmaudoux@klatch"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJe+dx4zrUGh1y8LmyI6jmKy1rdbvy8BmpglAsZ+PnwJ0E8VIzLAHFeBeP98stzdEoP7m6vvxBssyy42mKAdMsk= layus@uberwald"
    ];
    hostKeys = [ /etc/nixos/ssh_ecdsa_host_key ];
  };
  boot.initrd.availableKernelModules = [
    #"aes_x86_64"
    "aesni_intel"
    "cryptd"

    "ahci"
    "e1000e"
    "ehci-pci"
    #"pcieport"
    #"snb_uncore"
    "xhci_hcd"
  ];


  nixpkgs.config = {
    allowUnfree = true;
    #packageOverrides = pkgs: rec {
    #  urlwatch = unstable.urlwatch;
    #};
  };


  ## Security

  security.sudo = {
    enable = true;
    #wheelNeedsPassword = false;
    extraConfig = "Defaults:root,%wheel env_keep+=EDITOR";
  };
  #security.pam.enableSSHAgentAuth = true;

  # services.fail2ban.enable = true;
  # services.fail2ban.jails = {
  #   # Can kick you off your own server with spoofed ip packets.
  #   ssh-iptables = lib.mkForce "";
  #   lighttpd-phpmyadmin = ''
  #     enabled=true
  #     port=http,https
  #     action=iptables-multiport[name="lighttpd-phpmyadmin", port="http,https"]
  #     filter=lighttpd-phpmyadmin
  #     maxretry=0
  #   '';
  # };

  ## Boot

  boot.tmp.cleanOnBoot = true;

  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/sda" ];
    enableCryptodisk = true;
  };


  ## Nix

  system.autoUpgrade.enable = true;
  system.autoUpgrade.flags = [ "--override-input" "nixpkgs" "github:NixOS/nixpkgs/nixos-unstable" "--impure" ];
  system.autoUpgrade.flake = "/home/layus/.config/nixpkgs";

  system.stateVersion = "21.11";

  nix.gc = {
    automatic = true;
    dates = "06:06";
    options = "--delete-older-than 10d";
  };

  nix.settings = {
    cores = 4;
    max-jobs = 4;
    sandbox = true;
    trusted-users = [ "root" "@wheel" ];
  };
  #nix.package = pkgs.nixVersions.nix_2_8;
  nix.extraOptions = ''
    extra-experimental-features = nix-command flakes
  '';

  ## Users

  #users.defaultUserShell = "/run/current-system/sw/bin/zsh";
  users.defaultUserShell = "/run/current-system/sw/bin/fish";

  users.mutableUsers = true;

  users.extraUsers = {
    layus = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [ "wheel" "fileshare" ];
      openssh.authorizedKeys.keys = [
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEFMsq6kKxh2so5Jr+kzHmVNfg80aXIRYfFt3k6B2osiEJH7ibnZx51BTkFd42Ld6FifWb3WjjoyNYeAnGzruvg= gmaudoux@klatch"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAjd/cnsdiyS0k3ckRO8e8bTPd2amazA8vLT2WpRfHTHyastB7JYO1yDabICq+fgpkSXUgGRjQWMhKRHEFy5Ffc= layus@ankh-morpork"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJe+dx4zrUGh1y8LmyI6jmKy1rdbvy8BmpglAsZ+PnwJ0E8VIzLAHFeBeP98stzdEoP7m6vvxBssyy42mKAdMsk= layus@uberwald"
      ];
    };

    deluge = {
      isSystemUser = true;
      home = pkgs.lib.mkForce "/home/deluge"; # Use /home partition to store files.
      createHome = true;
      group = "deluge";
    };

    git = {
      home = "/srv/git";
      createHome = true;
      shell = "/run/current-system/sw/bin/git-shell";
      # openssh.authorizedKeys.keyFiles = [ ./layus_ecdsa.pub ];
      openssh.authorizedKeys.keys = [
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEFMsq6kKxh2so5Jr+kzHmVNfg80aXIRYfFt3k6B2osiEJH7ibnZx51BTkFd42Ld6FifWb3WjjoyNYeAnGzruvg= gmaudoux@klatch"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAjd/cnsdiyS0k3ckRO8e8bTPd2amazA8vLT2WpRfHTHyastB7JYO1yDabICq+fgpkSXUgGRjQWMhKRHEFy5Ffc= layus@ankh-morpork"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJe+dx4zrUGh1y8LmyI6jmKy1rdbvy8BmpglAsZ+PnwJ0E8VIzLAHFeBeP98stzdEoP7m6vvxBssyy42mKAdMsk= layus@uberwald"
      ];
      group = "git";
      isSystemUser = true;
    };

    brotherSftp = {
      isSystemUser = true;
      createHome = true;
      home = "/srv/brotherSftp";
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDgpNcUjGHyPjfLEwhsVwrPCa87Cqf3XNU+Ck2AaXvF1TNzQ9JPEWdKZ2mPN4v8bLvUMKD6oMckA0TdUfIJt0N0uUyH0Qrq22wT0wTUwppv6Ahnu6uM3a06qwEr3IxmPQ8RmNJWeyqCDeXp7W7okxIQbjBizv12LXzFMZ/5fb5MR/dUUWCt8jDLqi3XqlorPVdefNjifyYiTGkZfz7kA1m+UITzaO3UOFr1MGBXxhpyzh8FZ6RxTG09LKRWNLtXXSLRHK1a8zBjBeGdh5aFPkAFrZ5zIoAjEwq3uzF2w9ubdRe6o99nCiEtEZ5odjaayKjvM42t/Dx/u+oSYLyIeW8H root@BR5CF3705DEABB"
      ];
      group = "fileshare";
    };

    erin = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBG2HcFsg0lXkRwzXvNbYB1r6MQ6/ne5cG6zjvtnIkYiVjt5+0zcpwTWHAS+R6hQ/7++is0egZ2agIm823MatAAM= erin@gwen"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBGIxWy1Zpd1mH4/P6ZzBZRBLSUTDilbWbaARQp3N6WbJr8AwAguwqV8nuijys5Rl2IPHdVmJlcvkbnWOZwqdLkI= evandervee@ahose-uvm1"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIkCht2nrIsYCvkZOAZy64AgEtUZwsVSy4t6qg9ScSbp erin@Tequatl"
      ];
    };
  };

  users.extraGroups = {
    git = { };
    deluge = { };
    wheel = { };
    fileshare = { };
  };


  ## Services

  #services.minecraft-server = {
  #  enable = true;
  #  eula = true;
  #  openFirewall = true;
  #};

  services.syncthing = {
    enable = true;
    dataDir = "/home/syncthing";
    guiAddress = "10.66.0.1:8384";
    openDefaultPorts = true;
  };

  /*
    services.influxdb.enable = true;
    services.telegraf.enable = true;
    systemd.services.telegraf.serviceConfig.ExecStart = lib.mkForce ''${pkgs.telegraf}/bin/telegraf -config "/etc/telegraf.conf"'';
    services.grafana.enable = true;
    services.grafana.addr = "";
  */

  services.dante = {
    enable = false;
    config = ''
      internal: 10.66.0.1 port=1080
      #internal: eno0
      external: eno0

      clientmethod: none
      socksmethod: none

      client pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        log: error connect disconnect
      }

      pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        log: error connect disconnect
      }
    '';
  };

  #services.znc.enable = true;
  #services.znc.mutable = true;
  #services.znc.confOptions = {
  #  nick = "layus";
  #  passBlock = ''
  #    <Pass password>
  #      Method = sha256
  #      Hash = a8788d9099bf8b1481063f459a5aff54e5f8ba0b30da9d92f6edee1ccc179c33
  #      Salt = kGIT*D!h6eb:-G8VE1*w
  #    </Pass>
  #  '';
  #  useSSL = true;
  #  userName = "layus";
  #  port = 3333;
  #};

  ## Deluge
  #services.deluge.enable = true;
  #services.deluge.web.enable = true;
  #systemd.services.deluged.serviceConfig.CPUShares = 128;
  #systemd.services.deluged.serviceConfig.BlockIOWeight = 10;

  # Transmission
  #services.transmission.enable = true;
  #services.transmission.settings = {
  #  rpc-whitelist = "127.0.0.1,10.8.*.*";
  #  rpc-whitelist-enabled = true;
  #  #watch-dir = "/home/deluge/torrents/new";
  #  watch-dir-enabled = true;
  #  #download-dir = "/home/deluge/downloads";
  #  #incomplete-dir = "/home/deluge/downloads/active";
  #  incomplete-dir-enabled = true;
  #  preallocation = 2;
  #  rename-partial-files = false;
  #};

  services.ntp.enable = true;

  services.nix-serve.enable = true;


  # Matrix (synapse)
  #systemd.services.matrix-synapse.preStart = ''
  #  set -x
  #  synapse_dir=/etc/matrix-synapse
  #  le_dir=/etc/letsencrypt/live
  #  mkdir -p "$synapse_dir"
  #  chown matrix-synapse:matrix-synapse "$synapse_dir"
  #  chmod 700 "$synapse_dir"
  #  for dom in marie-guillaume.no-ip.org; do # {marie-guillaume,sto-lat,inginious}.no-ip.org; do
  #    cat $le_dir/$dom/privkey.pem > $synapse_dir/privkey.pem
  #    cat $le_dir/$dom/fullchain.pem > $synapse_dir/certificate.pem
  #  done
  #'';
  #
  #services.matrix-synapse = {
  #  enable = true;
  #  allow_guest_access = true;
  #  enable_metrics = true;
  #  enable_registration = true;
  #  server_name = "sto-lat.no-ip.org";
  #  tls_certificate_path = "/etc/matrix-synapse/certificate.pem";
  #  tls_private_key_path = "/etc/matrix-synapse/privkey.pem";
  #};

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  #services.gitlab = {
  #  enable = false;
  #  databasePassword = "gitlab";
  #};

  #systemd.services.samba-nmbd.enable = false;
  services.samba = {
    enable = true;
    winbindd.enable = true;
    nsswins = true;
    settings = {
      global = {
        "security" = "user";
        "workgroup" = "WORKGROUP";
        "server string" = "pigloo";
        "guest account" = "nobody";
        "map to guest" = "bad user";
        "interfaces" = [ "lo" "tun0" "tun1" "10.66.0.0/24" "127.0.0.1" "10.8.1.0/24" "10.8.0.0/24" ];
        "hosts allow" = [ "10.66.0.0/24" "10.8.0.0/24" "10.8.1.0/24" "127.0.0.1" ];
        "bind interfaces only" = false;

        # Turn samba into a WINS server
        "domain master" = true;
        "wins support" = true;
        "name resolve order" = "wins lmhosts host bcast";
        "netbios name" = "pigloo";

        # Enable debug
        "log level" = 2;
        #"log file" = "/var/log/samba.log.%m";
        #"max log size" = 50;
        "debug timestamp" = true;

        ## Printers
        # disable cups
        "load printers" = false;
        "printing" = "bsd";
        "printcap name" = "/dev/null";
        "disable spoolss" = true;
      };

      torrents = {
        "comment" = "Torrent related stuff";
        "path" = "/home/deluge";
        "public" = true;
        "available" = true;
        "guest ok" = true;
        "writable" = true;
        "read only" = false;
        "browsable" = true;
      };
    }; # services.samba.settings
  }; # services.samba

  services.openssh = {
    enable = true;
    ports = [ 3248 22 ];
    #openFirewall = false; # BEWARE !!!
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KexAlgorithms = [
        "curve25519-sha256@libssh.org"
        "diffie-hellman-group-exchange-sha256"
        "diffie-hellman-group14-sha1"
      ];
      Macs = [
        # defaults
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
        "hmac-sha2-512"
        "hmac-sha2-256"
        "umac-128@openssh.com"
        # brother...
        #"hmac-ripemd160"
        #"hmac-ripemd160@openssh.com"
        "hmac-sha1"
        "hmac-sha1-96"
      ];
    };
    extraConfig = ''
      Match user brotherSftp
        ChrootDirectory /srv/brotherSftp
        ForceCommand internal-sftp
        AllowTCPForwarding no
      Match all
    '';
  };

  services.openvpn.servers = {
    server = {
      config = builtins.readFile ./openvpn-server.conf;
    };
    server-redirect = {
      config = builtins.readFile ./openvpn-server-redirect.conf;
    };
  };

  #services.hydra = {
  #  enable = true;
  #  hydraURL = "hydra.maudoux.be:3000";
  #  notificationSender = "hydra@sto-helit.maudoux.be";
  #  useSubstitutes = true;
  #};
  nix.buildMachines = [
    {
      hostName = "localhost";
      system = "x86_64-linux";
      supportedFeatures = [ "kvm" "nixos-test" "big-parallel" "benchmark" ];
      maxJobs = 4;
    }
  ];

  systemd.timers.urlwatch.timerConfig.RandomizedDelaySec = 8 /*hours*/ * 60 * 60;
  systemd.services.urlwatch = rec {
    description = "Run urlwatch (${startAt})";
    startAt = "daily";

    serviceConfig = {
      User = "layus";
      ExecStart = "${pkgs.urlwatch}/bin/urlwatch -v";
    };

  };

  #services.openldap.enable = true;

  services.radicale.enable = true;
  #services.radicale.extraArgs = [ "--debug" ];
  services.radicale.settings = {
    server = {
      # Bind all addresses
      hosts = "0.0.0.0:5232";
      ssl = "True";
      key = "/var/run/radicale/certificates/privkey.pem";
      certificate = "/var/run/radicale/certificates/fullchain.pem";
    };

    logging.level = "info";

    auth = {
      type = "htpasswd";
      htpasswd_filename = "/var/lib/radicale/users";
      htpasswd_encryption = "bcrypt";
    };

    storage.filesystem_folder = "/var/lib/radicale/collections";

    web.type = "internal";

    # # The first rule matching both user and collection patterns will be returned.

    # # Allow authenticated user to read 'shared' collections in their home directory
    # # (usually symlinks from other calendars)
    # [allow-shared-read]
    # user: .+
    # collection: %(login)s/.+-shared.ics$
    # permission: r

    # # Give owners read-write access to everything else:
    # [owner-write]
    # user: .+
    # collection: %(login)s.*$
    # permission: rw
  };

  systemd.services.radicale.serviceConfig.PermissionsStartOnly = true;
  systemd.services.radicale.preStart = ''
    set -xe
    mkdir -p /var/run/radicale/certificates
    chmod 700 /var/run/radicale /var/run/radicale/certificates
    chown radicale:radicale /var/run/radicale /var/run/radicale/certificates
    rm -rf /var/run/radicale/certificates/*

    radicale_dir=/var/run/radicale/certificates
    le_dir=/etc/letsencrypt/live

    for dom in maudoux.be; do
      install -m 440 -o root -g radicale -t $radicale_dir $le_dir/$dom/privkey.pem
      install -m 440 -o root -g radicale -t $radicale_dir $le_dir/$dom/fullchain.pem
    done
  '';

  systemd.services."status-email-user@" = {
    enable = true;
    scriptArgs = "%i";
    script = with config.networking; ''
      /run/wrappers/bin/sendmail -t <<ERRMAIL
      To: layus.on@gmail.com
      From: ${hostName} <root@${hostName}.${domain}>
      Subject: $1 failed
      Content-Transfer-Encoding: 8bit
      Content-Type: text/plain; charset=UTF-8

      $(${pkgs.systemd}/bin/systemctl status --full "$1")
      ERRMAIL
    '';
    description = "Status email from %i to layus";
    serviceConfig = {
      User = "nobody";
      Group = "systemd-journal";
      Type = "oneshot";
    };
  };
  systemd.services.nixos-upgrade.onFailure = [ "status-email-user@%n.service" ];
  systemd.services.urlwatch.onFailure = [ "status-email-user@%n.service" ];

  programs.zsh.enable = true;
  programs.fish.enable = true;
  documentation.man.generateCaches = false; # man-cache does not build properly

  programs.bash.completion.enable = true;

  ## Networking

  #networking.hostName = "sto-lat";
  #networking.domain = "maudoux.be";
  networking.enableIPv6 = true;

  networking.nat = {
    enable = true;
    internalIPs = [ "10.8.0.0/24" "10.8.1.0/24" ];
    externalInterface = "eno1";
  };

  networking.interfaces.lo = {
    ipv4.addresses = [{ address = "10.66.0.1"; prefixLength = 24; }];
    ipv4.routes = [{ address = "10.66.0.0"; prefixLength = 24; }];
  };

  networking.firewall = {
    enable = true;
    allowPing = true;
    logRefusedConnections = false; # Too verbose on an OVH server apparently :-/

    allowedTCPPorts = [
      22
      3248 # ssh (not auto, and better safe than sorry)
      # samba (over vpn)
      8112 # deluge-web
      80 # http
      443 # https
      1080 # dante
      3000 # hydra
      5232 # radicale
      #8080  # owncloud
      #8008 8448  # matrix-synapse
      25565 # minecraft
    ];

    allowedTCPPortRanges = [
      { from = 55248; to = 55258; } # deluge server
    ];

    allowedUDPPorts = [
      1194 # openvpn (redirect)
      1195 # openvpn
      5228 # sfr...
    ];

    trustedInterfaces = [ "tun+" ];

    #extraCommands = ''
    #  iptables -A INPUT -p 22 -s 204.27.197.0/24 -j ACCEPT # for intusurg.com reverse connection
    #'';
  };


  ## Environment

  time.timeZone = "Europe/Brussels";

  i18n = rec {
    defaultLocale = "en_GB.UTF-8";
    supportedLocales = [ "en_GB.UTF-8/UTF-8" "fr_BE.UTF-8/UTF-8" ];
  };
  console.font = "lat9w-16";
  console.keyMap = "be-latin1";

  #environment.noXlibs = true;

  environment.variables = {
    LC_TIME = "fr_BE.UTF-8";
    LC_COLLATE = "fr_BE.UTF-8";
    EDITOR = "vim";
  };

  environment.systemPackages = with pkgs; [
    vim # Decent file editor
    git # Fetch configuration files
    # TODO: temporary build failure
    #vcsh              # Manage configuration files
    #lynx              # Emergency web access
    htop
    atop # List processes
    #iotop             # Disk usage
    certbot

    #imagemagick      # imagemagick, for lychee
    urlwatch # provide the system version
    rxvt-unicode-unwrapped.terminfo
    termite.terminfo
  ];


  # Packages

  nixpkgs.overlays = [ (import ./piwigo.nix) ];
  #nixpkgs.config = {
  #  packageOverrides = pkgs: {
  #  };
  #};


  # Services

  services.postfix = {
    enable = true;
    setSendmail = true;
  };

  # dotfiles is not safe : services.lighttpd.gitweb.enable = true;

  #services.lighttpd.inginious = {
  #  enable = false;
  #  tasksDirectory = "/home/tasks" ;
  #  superadmins = [ "gmaudoux" "layus" "test" ];
  #};

  #services.mongodb.extraConfig = ''
  #  nojournal = true
  #'';

  #services.lighttpd.extraConfig = ''
  #  #debug.log-request-handling = "enable"
  #  #debug.log-condition-handling = "enable"
  #'';

  # Postgres (who needs this ?)
  services.postgresql.enable = true;
  services.postgresql.package = pkgs.postgresql_14;

  # OwnCloud
  #services.cron.systemCronJobs = [
  #  # "*/15 * * * * wwwrun ${pkgs.php.out}/bin/php -f ${pkgs.owncloud}/cron.php"
  #];
  #services.httpd = let
  #  owncloud = {
  #    dataDir = "/home/owncloud";
  #    serviceType = "owncloud";
  #    siteName = ''"My own cloud"'';
  #    adminUser = "admin";
  #    adminPassword = "zeqfmjeziqjfoiazje3resifje5fqoihefioqezumèqlfjzeifzefe!";
  #    dbPassword = "test2";
  #    trustedDomain = "10.8.1.1:8080', 'sto-lat.no-ip.org:8080', 'pigloo:8080";
  #    #libreofficePath = "${pkgs.libreoffice}/bin/libreoffice";
  #  };
  #in {
  #  #enable = true;
  #  adminAddr = "layus.on@gmail.com";
  #  hostName = "sto-lat.no-ip.org";
  #  port = 8080;
  #
  #  enablePHP = true; /* of course, maybe owncloud does it... */
  #  extraSubservices = [
  #    owncloud #useless ?
  #  ];
  #
  #  phpOptions = ''
  #    zend_extension=opcache.so
  #    zend_extension=acpu.so
  #    '';
  #
  #  /* Nop !
  #     extraConfig = ''
  #     <Directory ${pkgs.owncloud}>
  #     SetEnv MOD_X_SENDFILE_ENABLED 1
  #     XSendFile On
  #     XSendFilePath ${owncloud.dataDir}
  #     </Directory>
  #     '';
  #  # */
  #};
}

