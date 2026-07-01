{ config, lib, pkgs, ... }:

{
  # Package overrides now live in pkgs/overlays/default.nix, composed into the
  # flake's overlays.default so they're visible to NixOS, home-manager, and
  # anything built with super.callPackage later in the chain (e.g. sway-config).

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
        poppler-utils
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
        #calibre
        gimp #gimp-with-plugins
        slack
        element-desktop
        #mozart2 # build fails ?!
        #(builtins.storePath /nix/store/8i227iqjsaq7g4ddbrav6jn6w2lbxs9l-mozart2-2.0.0-beta.1)
        zim
        zoom-us
        #texmaker
        #typora # error: Newer versions of typora use anti-user encryption and refuse to start.
        inkscape
        #yed
        hexchat
        vlc
        guvcview
        krita
        # freecad #coin3D hash mismatch

        wireshark

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
        #helvum  # removed from nixpkgs (unmaintained, vulnerable dep)
        wdisplays
        wtype
        xkill
        xrandr
        arandr
        autorandr # display management
        xev
        xclock
        meld
        gnuplot
        zenity
        qtikz
        gnome-settings-daemon
        vscode

        slurp
        grim

        alacritty
        ghostty
        # BROKEN: enlightenment.terminology
        st

        tpm-fido
        pinentry-gnome3
        windsurf
        # }}}

        # {{{ Admin (graphical)
        wev
        ydotool
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
      editorconfig-core-c # Was is das ?
      #neovim
      emacs
      #(mercurialFull.overrideAttrs (oldAttrs: {
      #  propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or []) ++ [ pythonPackages.simplejson ]; # for mozilla pushtree
      #}))
      subversion # VCS
      hub
      gh
      tree
      eza
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
      zellij
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
      patchelf
      binutils
      gdb
      #mypkgs.EMV-CAP
      readlinks
      #mypkgs.monitormonitors
      sqlite-interactive
      inotify-tools
      # jotta-cli: installed by the services.jotta-cli module (uberwald only)
      #rnix-hashes # unmaintained, but was so useful
      nix-output-monitor

      # }}}
      # {{{ Admin
      htop
      (lib.lowPrio openssl)
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
      bazel_8
      #(if true then (lib.hiPrio gcc6) else gcc)
      #jre
      jdk

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
