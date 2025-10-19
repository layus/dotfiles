{ config
, pkgs
, lib
, ...
}: {
  config = lib.mkMerge [
    {
      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;

      # Home Manager needs a bit of information about you and the
      # paths it should manage.
      home.username = lib.mkDefault "layus";
      home.homeDirectory = lib.mkDefault "/home/layus";

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
        userName = lib.mkDefault "Guillaume @layus Maudoux";
        userEmail = lib.mkDefault "layus.on@gmail.com";
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

      programs.fish.enable = true;
      programs.zsh.enable = true;
      programs.zsh.autocd = true;
      programs.zsh.history.path = "/home/layus/.histfile";
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

      programs.helix.enable = true;
      programs.helix.languages = {
        haskell = {
          language-server = {
            command = "haskell-language-server";
            args = [ ];
          };
        };
      };

      home.sessionVariables.EDITOR = "nvim";
      programs.neovim.enable = true;
      #programs.neovim.extraConfig = builtins.readFile ../dotfiles/vimrc;
      programs.neovim.withPython3 = true;
      programs.neovim.extraPackages = [
        pkgs.nodejs
        (pkgs.python3.withPackages (ps:
          with ps; [
            pep8
            black
          ]))
      ];
      programs.neovim.plugins = with pkgs.vimPlugins; [
        ale
        vim-easymotion
        #switch.vim
        supertab
        vim-fugitive
        vim-rhubarb
        vim-sleuth
        nerdtree
        csapprox
        vim-colors-solarized
        vim-surround
        vim-unimpaired
        vim-airline
        vim-airline-themes
        nerdcommenter
        neoformat
        #vim-oz
        #vim-alloy
        #jsonc.vim
        #vim-i3-config-syntax
        #sway-vim-syntax
        vim-loves-dafny
        vim-scala
        vim-nix
        #vim-zimwiki-syntax
        #vim-jenkinsfile
        #vim-mustache-handlebars
        #groovy.vim
        vim-pandoc
        vim-pandoc-syntax
        #zotcite
        limelight-vim
        goyo
        #unicode
        #vim-ingo-library
        vim-SyntaxRange
        vim-endwise
        deoplete-nvim
        #nvim-lspconfig
        nvim-yarp
        #vim-hug-neovim-rpc
        #neocomplcache
        #neco-ghc -- needs more of ghc installed
        editorconfig-vim
        syntastic
        #vim-latex
        rust-vim #rust.vim
        vim-racer
        fzf-vim
        vim-bazel
      ];

      home.file.".bash_aliases".source = ../dotfiles/bash_aliases;
      home.file.".bash_aliases.git".source = ../dotfiles/bash_aliases.git;

      xdg.mime.enable = true;
      xdg.mimeApps.enable = true;
      xdg.configFile."mimeapps.list".source = lib.mkForce ../dotfiles/mimeapps.list;

      programs.ssh.enable = true;
      programs.ssh.enableDefaultConfig = false;
      home.file.".ssh/config".text = lib.mkOrder 999 (builtins.readFile ../dotfiles/ssh/config);
      home.file.".ssh/pubkeys" = {
        source = ../dotfiles/ssh/pubkeys;
        recursive = true;
      };
      home.file.".ssh/id_ecdsa.pub".source = ../dotfiles/ssh/pubkeys/uberwald_ecdsa.pub;

      xdg.userDirs = {
        enable = true;
        createDirectories = true;
        desktop = "$HOME";
        documents = "$HOME/documents";
        download = "$HOME/downloads";
        music = "$HOME/documents/music";
        pictures = "$HOME/images";
        publicShare = "$HOME/documents/public";
        templates = "$HOME/documents/templates";
        videos = "$HOME/documents";
        extraConfig = {
          XDG_PROJECTS_DIR = "$HOME/projects";
          XDG_PRINT_SCREEN_DIR = "$HOME/images/captures";
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
            propagatedBuildInputs = oldAttrs.propagatedBuildInputs or [ ] ++ [ self.python3Packages.Babel ];
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

      programs.termite.enable = true;
      xdg.configFile."termite/config".source = ../dotfiles/termite;

      programs.firefox = {
        enable = true;
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
        enable = true;
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
    })
  ];
}
