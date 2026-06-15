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

      programs.direnv.enable = true;
      programs.direnv.nix-direnv.enable = true;
      programs.dircolors.enable = true;
      #programs.keychain.enable = true;  # Nope, deal with it ourselves.

      # Disable fish. Generating completions takes ages.
      #programs.fish.enable = true;

      programs.zsh.enable = true;
      programs.zsh.autocd = true;
      programs.zsh.history.path = "${config.home.homeDirectory}/.histfile";
      programs.zsh.history.size = 100000;
      programs.zsh.history.ignoreAllDups = true;
      programs.zsh.history.ignoreSpace = true;
      programs.zsh.history.ignorePatterns = [ "rm *" "pkill *" ];
      programs.zsh.history.append = true;
      programs.zsh.history.share = false;
      programs.zsh.initContent =
        (builtins.readFile ../dotfiles/zshrc +
          ''
            direnv_completions_hook () {
              export FPATH=$ZSH_COMPLETION_USER_DIR''${ZSH_COMPLETION_USER_DIR:+:}$FPATH
              if [ "$FPATH" != "$OLD_FPATH" ]; then
                functions -u _ox # mark _ox as undefined, will get reloaded if needed
                compinit -D
              fi
              export OLD_FPATH=$FPATH
            }
            precmd_functions+=(direnv_completions_hook)
          '')
      ;

      # On machines where the login shell cannot be changed (e.g. it is
      # stuck on bash in /etc/passwd), transparently switch to zsh on
      # interactive logins. The guards keep scp/rsync/`ssh host cmd` and
      # scripts working, and prevent infinite loops if zsh falls back to
      # bash.
      #programs.bash.enable = true;
      #programs.bash.initExtra = ''
      #  if [[ $- == *i* ]] && [[ -z "$ZSH_LAUNCHED" ]] && command -v zsh >/dev/null; then
      #    export ZSH_LAUNCHED=1
      #    exec zsh -l
      #  fi
      #'';

      programs.helix.enable = true;
      programs.helix.languages = {
        haskell = {
          language-server = {
            command = "haskell-language-server";
            args = [ ];
          };
        };
      };

      home.file.".bash_aliases".source = ../dotfiles/bash_aliases;
      home.file.".bash_aliases.git".source = ../dotfiles/bash_aliases.git;

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
