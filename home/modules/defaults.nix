{ config
, pkgs
, lib
, ...
}:
let
  pubkeyFile = ../dotfiles/ssh/pubkeys + "/${config.custom.hostname}_ecdsa.pub";
  hasPubkey = builtins.pathExists pubkeyFile;
in
{
  config = lib.mkMerge [
    {
      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;

      # Home Manager needs a bit of information about you and the
      # paths it should manage.
      home.username = lib.mkDefault "layus";
      home.homeDirectory = lib.mkDefault "/home/${config.home.username}";

      # This value determines the Home Manager release that your
      # configuration is compatible with. This helps avoid breakage
      # when a new Home Manager release introduces backwards
      # incompatible changes.
      #
      # You can update Home Manager without changing this value. See
      # the Home Manager release notes for a list of state version
      # changes in each release.
      home.stateVersion = lib.mkDefault "21.11";

      home.activation = {
        mySymlinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          [ -e .terminfo -o -L .terminfo ] || run ln -sn $VERBOSE_ARG .nix-profile/share/terminfo .terminfo
          [ -e .config/home-manager -o -L .config/home-manager ] || run ln -sn $VERBOSE_ARG ../.config/nixpkgs .config/home-manager
        '';
      };

      programs.git = {
        enable = true;
        package = pkgs.gitFull;
        settings.user.name = lib.mkDefault "Guillaume @layus Maudoux";
        settings.user.email = lib.mkDefault "layus.on@gmail.com";
        includes = [{ path = ../gitconfig.inc; }];
        lfs.enable = true;
      };

      nixpkgs.config =
        (import ../dotfiles/nixpkgs-config.nix)
        // {
          allowUnfreePredicate = pkg: builtins.trace "Using unfree package ${lib.getName pkg}." true;
        };
      xdg.configFile."nixpkgs/config.nix".source = ../dotfiles/nixpkgs-config.nix;

      programs.helix.enable = true;
      programs.helix.languages = {
        haskell = {
          language-server = {
            command = "haskell-language-server";
            args = [ ];
          };
        };
      };

      programs.ssh.enable = true;
      programs.ssh.enableDefaultConfig = false;
      home.file.".ssh/config".text = lib.mkOrder 999 (builtins.readFile ../dotfiles/ssh/config);
      home.file.".ssh/pubkeys" = {
        source = ../dotfiles/ssh/pubkeys;
        recursive = true;
      };
      home.file.".ssh/id_ecdsa.pub" = lib.mkIf hasPubkey {
        source = pubkeyFile;
        force = true;
      };

      xdg.userDirs = {
        enable = true;
        createDirectories = true;
        setSessionVariables = true;
        desktop = "$HOME";
        documents = "$HOME/documents";
        download = "$HOME/downloads";
        music = "$HOME/documents/music";
        pictures = "$HOME/images";
        publicShare = "$HOME/documents/public";
        templates = "$HOME/documents/templates";
        videos = "$HOME/documents";
        extraConfig = {
          PROJECTS = "$HOME/projects";
          PRINT_SCREEN = "$HOME/images/captures";
        };
      };
    }

    # Graphical defaults
    (lib.mkIf config.custom.graphical {
      wayland.windowManager.sway.enable = true;
      wayland.windowManager.sway.wrapperFeatures = {
        base = true; # not too sure.
        gtk = true;
      };

      xdg.configFile."sway/config".source = lib.mkForce "${pkgs.sway-config}/etc/sway/config";

      home.sessionVariables.NIXOS_OZONE_WL = "1";

      # Kanshi exists only as a systemd user service.
      # I prefer to start it from sway config, as it ensures a proper restart/reload
      #services.kanshi.enable = true;
      xdg.configFile."kanshi" = {
        source = ../dotfiles/kanshi;
        recursive = true;
      };

      nixpkgs.overlays = [
        (self: super: {
          sway-config = super.callPackage ../sway.nix { };
          lockimage = pkgs.runCommand "background.jpg" { } ''
            ${pkgs.imagemagick}/bin/convert ${../dotfiles/background.webp} -resize "3840x2400^" -gravity Center -extent 3840x2400+250 $out
          '';
          zim = super.zim.overrideAttrs (oldAttrs: {
            propagatedBuildInputs = oldAttrs.propagatedBuildInputs or [ ] ++ [ self.python3Packages.babel ];
            preFixup =
              oldAttrs.preFixup
                or ""
              + ''
                makeWrapperArgs+=(--set LC_ALL fr_BE.UTF-8)
              '';
          });
          # TODO: do not use pinned versions without version checks !
          #sway = super.sway.overrideAttrs (_: {
          #  src = self.fetchFromGitHub {
          #    owner = "swaywm";
          #    repo = "sway";
          #    rev = "master";
          #    hash = "sha256-0gZP2Pe2LsMzScKKRL/q98ERJQuqxa1Swwi9DY/KCvg=";
          #  };
          #});
        })
      ];

      xdg.configFile."waybar" = {
        source = ../dotfiles/waybar;
        recursive = true;
      };

      programs.alacritty.enable = true;
      xdg.configFile."alacritty/alacritty.toml".source = ../dotfiles/alacritty.toml;

      programs.firefox = {
        enable = true;
        configPath = ".mozilla/firefox";
        profiles.default = {
          userChrome = builtins.readFile ../dotfiles/userChrome.css;
        };
        package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
          extraPolicies = {
            ExtensionSettings = { };
          };
        };
      };

      services.mako.enable = true;
      xdg.configFile."mako/config".source = ../dotfiles/mako;

      programs.obs-studio = {
        enable = true;
        plugins = [ pkgs.obs-studio-plugins.wlrobs ];
      };

      services.activitywatch = {
        enable = false; # temporarily disabled: aw-webui build is broken
        watchers = {
          aw-watcher-window-wayland = {
            package = pkgs.aw-watcher-window-wayland;
            settings = {
              poll_time = 5;
            };
          };
        };
      };


      #programs.vscode = {
      #  enable = true;
      #  package = {pname = "vscodium"; } // pkgs.vscode-with-extensions.override {
      #    vscode = pkgs.vscodium;
      #    vscodeExtensions = with pkgs.vscode-extensions; [
      #      # Some example extensions...
      #      vscodevim.vim
      #      yzhang.markdown-all-in-one
      #      jnoortheen.nix-ide
      #      brettm12345.nixfmt-vscode
      #      ms-vsliveshare.vsliveshare
      #    ];
      #  };
      #};

      # Reload sway after all config changes are applied (catches sway, waybar, etc.)
      home.activation.reloadSway = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -n "''${WAYLAND_DISPLAY:-}" ] && command -v swaymsg &>/dev/null; then
          $DRY_RUN_CMD swaymsg reload || true
        fi
      '';
    })
  ];
}
