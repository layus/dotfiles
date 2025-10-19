{ config, lib, pkgs, ... }:

{
  nixpkgs.overlays = [
    (self: super: {

      # now on by default
      #firefox = super.wrapFirefox super.firefox-unwrapped { forceWayland = true; };

      #thunderbird = super.thunderbird-78;

      #jotta-cli = super.jotta-cli.overrideAttrs (oldAttrs: rec {
      #  arch = "amd64";
      #  version = "0.12.51202";
      #  pname = "jotta-cli";
      #  name = "${pname}-${version}";
      #  src = super.fetchzip {
      #    url = "https://repo.jotta.us/archives/linux/amd64/jotta-cli-${version}_linux_amd64.tar.gz";
      #    hash = "sha256-B7Rn/0hFVUsEK2Wo8KbqAnzOwQmMKkAssfmaN3dPAUY=";
      #    stripRoot = false;
      #  };
      #});

      factorio = super.factorio.overrideAttrs (oldAttrs: rec {
        version = "2.0.32";
        pname = "factorio";
        name = "${pname}-${version}";
        src = super.requireFile {
          url = "https://dl.factorio.com/releases/factorio_alpha_x64_${version}.tar.xz";
          hash = "sha256:0xrx5snnsln4az47h7vxamh0zgsf8lcrdxm01qh5w0b5svcwmcai";
        };
      });

      systembus-notify = super.systembus-notify.overrideAttrs (oldAttrs: {
        patches = oldAttrs.patches or [ ] ++ [ ./systembus-notify.patch ];
      });

      emv-cap = self.python3Packages.buildPythonApplication rec {
        name = "EMV-CAP-${version}";
        version = "1.6";

        src = super.fetchFromGitHub {
          owner = "doegox";
          repo = "EMV-CAP";
          # rev = master @ v1.6 (untagged)
          # title = Fix setup.py: license, requirements & bump version
          rev = "d28dbdd77b57fe2489d0f3d452a5b716a0852949";
          hash = "sha256-K6uLrkkoWZVByB8toclHRYnVf79dyvMQPQOvDgFvcHo=";
        };

        propagatedBuildInputs = with self.python3Packages; [ pyscard pycrypto ];
        pyproject = true;
        build-system = with self.python3Packages; [ setuptools ];
      };

      #wlroots = super.wlroots_0_16.overrideAttrs (oldAttrs: {
      #  patches = oldAttrs.patches or [] ++ [ ./wlroots-reversed.patch ];
      #});

      timesheets-prompt = super.callPackage ../pkgs/by-name/ti/timesheets-prompt { };

      slurp = assert builtins.compareVersions "1.3.2" super.slurp.version <= 0;
        super.slurp.overrideAttrs (oldAttrs: {
          #patches = oldAttrs.patches or [] ++ [(
          #  super.fetchpatch {
          #    url = "https://patch-diff.githubusercontent.com/raw/emersion/slurp/pull/77.patch";
          #    sha256 = "sha256-tXB9SbYucXFxVpwlh2G+GC/f7Ihebhe00Oqfd0F89H4=";
          #  }
          #)];
          src = super.fetchFromGitHub {
            #owner = "emersion";
            owner = "wisp3rwind";
            repo = "slurp";
            rev = "fixed_aspect_ratio";
            #hash = "sha256-4/J9YHDf7V9YzT2CrvHy8WlLZpuGixFEcUo9mW4h7Nc=";
            #hash = "sha256-3OVHZl0NhzOlbiGR6k5NnBhWBDDTj94ccZg99ZsGIV0=";
            hash = "sha256-9x+6nb+QnBsbndX9GpJYvi1czRkZ9qArLgs4a3gzHhQ=";
          };
        });

    })
  ];



  #all = super.buildEnv {
  #  # This creates an indirection.
  #  # Nix-env will install this as the only package, creating a layer of symlinks.
  #  # But installing this directly as the main derivation prevents to add temporary derivations using nix-env
  #  # Basically we want to keep it. Live with it !
  #  name = "gmaudoux-package-set";
  #  #pathsToLink = ???
  #  extraOutputsToInstall = [ "man" "info" "docdev" ];
  #  ignoreCollisions = true;
  #  paths = with self; [

  home.packages = with pkgs; lib.mkMerge [
    (lib.mkIf
      config.custom.graphical
      [

        # {{{ special
        #converted to plugins: obs-wlrobs obs-studio // see home manager
        # RIP: xournal
        wf-recorder
        poppler_utils
        # teams -- unmainained
        #kdenlive
        # }}}

        # {{{ Graphical applications
        #firefox /*-bin*/
        apostrophe
        thunderbird
        chromium
        libreoffice # Not yet cached...
        gnumeric
        calibre
        gimp #gimp-with-plugins
        slack
        element-desktop
        #mozart2 # build fails ?!
        #(builtins.storePath /nix/store/8i227iqjsaq7g4ddbrav6jn6w2lbxs9l-mozart2-2.0.0-beta.1)
        zim
        zoom-us
        texmaker
        #typora # error: Newer versions of typora use anti-user encryption and refuse to start.
        inkscape
        #yed
        hexchat
        vlc
        guvcview
        krita
        # freecad #coin3D hash mismatch

        wireshark-qt

        #jetbrains.idea-community
        #jetbrains.pycharm-community

        #virtualbox
        zotero

        # }}}
        # {{{ Desktop environment
        gnome-themes-extra # For firefox and thunderbird theming.
        evince
        eog
        nautilus
        file-roller
        gedit
        pavucontrol
        xclip
        imagemagickBig
        (sox.override { enableLame = true; })
        pdfpc
        #gstreamer
        #gst-plugins-base
        #gst-plugins-good
        #gst-plugins-bad
        #gst-plugins-ugly
        #gst-ffmpeg
        gtkspell3
        gitg
        networkmanagerapplet
        simple-scan
        emv-cap

        #citrix_workspace

        # support both 32- and 64-bit applications
        #wineWowPackages.stable
        #winetricks

        kanshi
        #(hugin.overrideAttrs (oldAttrs: {
        #  nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ wrapGAppsHook ];
        #}))

        # }}}

        # {{{ More Stuff

        waypipe
        wl-clipboard
        helvum
        wdisplays
        xorg.xkill
        xorg.xrandr
        arandr
        autorandr # display management
        xorg.xev
        #xorg.xclock
        meld
        gnuplot
        zenity
        qtikz
        gnome-settings-daemon

        slurp
        grim

        termite
        alacritty
        ghostty
        # BROKEN: enlightenment.terminology
        st

        tpm-fido
        pinentry
        # }}}

        # {{{ Nix internals fixup
        shared-mime-info
        gtk3
        glib.dev
        desktop-file-utils
        texinfo

        # }}}

      ])

    # Non-graphical packages, always there
    [
      # {{{ Console
      (python3.withPackages (ps: with ps; [
        requests
        pygments
      ]))
      #(csvkit.overrideAttrs (oldAttrs: {
      #  propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or "") ++ [ python3Packages.setuptools ];
      #}))
      #rxvt_unicode-with-plugins
      #vim_configurable
      termite.terminfo
      editorconfig-core-c # Was is das ?
      #neovim
      emacs
      #(mercurialFull.overrideAttrs (oldAttrs: {
      #  propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or []) ++ [ pythonPackages.simplejson ]; # for mozilla pushtree
      #}))
      subversion # VCS
      gitAndTools.hub
      gitAndTools.gh
      tree
      ripgrep
      fd
      fzf
      ctags
      file
      zip
      unzip
      jshon
      fzf
      lynx
      screen
      #ghostscript # Why is this needed ? conflicts with texlive.
      # => Maybe for converting pdf to text.
      diffutils
      colordiff
      wdiff
      graphviz
      #nixUnstable
      niv
      ffmpeg
      # fails - diffoscope
      pdfgrep
      rsync
      borgbackup
      direnv
      bat
      hyperfine
      jq
      yq
      tmux
      tmate
      nixpkgs-fmt
      quilt
      keychain
      wget
      curl


      # }}}
      # {{{ Misc
      #((rustChannelOf { channel = "nightly"; date = "2019-02-04"; }).rust.override { extensions = [ "clippy-preview" "rust-src" ]; })
      man-pages
      #eid-viewer # does not exist anymore ?
      parallel
      pv
      psmisc # contains `killall`
      dnsutils # contains `dig`
      vcsh # To manage dotfiles
      #tup
      gawk
      biber
      #gnome.gconf #missinig
      gnumake
      tup
      #(lib.lowPrio remake)
      (lib.lowPrio moreutils)
      pandoc
      (lib.lowPrio (# conflicts wit ghostscript
        texlive.combine {
          inherit (texlive) scheme-full;
          #inherit (default) auctex;
          pkgFilter = pkg: pkg.tlType == "run" || pkg.tlType == "bin" || pkg.pname == "pgf";
        }
      ))
      patchelf
      binutils
      gdb
      #mypkgs.EMV-CAP
      #readlinks
      #mypkgs.monitormonitors
      sqlite-interactive
      inotify-tools
      #jotta-cli
      #rnix-hashes # unmaintained, but was so useful
      nix-output-monitor

      # }}}
      # {{{ Admin
      wev
      htop
      (lib.lowPrio openssl)
      ydotool
      xdg-utils

      # }}}
      # {{{ Courses
      #dafny
      #vscode # mono # mono explicitly required by VSCode to run dafny

      #(pkgs.vscode-with-extensions.override {
      #    #vscode = pkgs.vscodium;
      #    vscodeExtensions = with pkgs.vscode-extensions; [
      #      # Some example extensions...
      #      vscodevim.vim
      #      yzhang.markdown-all-in-one
      #      jnoortheen.nix-ide
      #      brettm12345.nixfmt-vscode
      #      ms-vsliveshare.vsliveshare
      #    ];
      #  }
      #)
      vscode
      bazel_8
      #(if true then (lib.hiPrio gcc6) else gcc)
      #jre
      jdk

      xorg.xclock

      # }}}
    ]
  ];

  #    postBuild = ''
  #      if [ -x $out/bin/update-mime-database -a -w $out/share/mime ]; then
  #          XDG_DATA_DIRS=$out/share $out/bin/update-mime-database -V $out/share/mime > /dev/null
  #      fi
  #
  #      if [ -x $out/bin/gtk-update-icon-cache -a -f $out/share/icons/hicolor/index.theme ]; then
  #          $out/bin/gtk-update-icon-cache $out/share/icons/hicolor
  #      fi
  #
  #      if [ -x $out/bin/glib-compile-schemas -a -w $out/share/glib-2.0/schemas ]; then
  #          $out/bin/glib-compile-schemas $out/share/glib-2.0/schemas
  #      fi
  #
  #      if [ -x $out/bin/update-desktop-database -a -w $out/share/applications ]; then
  #          $out/bin/update-desktop-database $out/share/applications
  #      fi
  #
  #      if [ -x $out/bin/install-info -a -w $out/share/info ]; then
  #        shopt -s nullglob
  #        for i in $out/share/info/*.info $out/share/info/*.info.gz; do
  #            $out/bin/install-info $i $out/share/info/dir
  #        done
  #      fi
  #    '';
}
