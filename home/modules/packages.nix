{ config, lib, pkgs, ... }:

{
  nixpkgs.overlays = [
    (self: super: {

      firefox = super.wrapFirefox super.firefox-unwrapped { forceWayland = true; };

      #thunderbird = super.thunderbird-78;

      jotta-cli = super.jotta-cli.overrideAttrs (oldAttrs: rec {
        arch = "amd64";
        version = "0.12.51202";
        pname = "jotta-cli";
        name = "${pname}-${version}";
        src = super.fetchzip {
          url = "https://repo.jotta.us/archives/linux/amd64/jotta-cli-${version}_linux_amd64.tar.gz";
          hash = "sha256-B7Rn/0hFVUsEK2Wo8KbqAnzOwQmMKkAssfmaN3dPAUY=";
          stripRoot = false;
        };
      });

      # teams = super.teams.overrideAttrs (oldAttrs: {
      #   installPhase = ''
      #     runHook preInstall
      #     ${oldAttrs.installPhase}
      #     runHook postInstall
      #   '';
      #   postInstall = (oldAttrs.postInstall or "") + ''
      #     mv $out/opt/teams/resources/app.asar.unpacked/node_modules/slimcore/bin/rect-overlay{,-do-not-use}
      #   '';
      # });

      citrix_workspace_custom = (
        assert builtins.compareVersions super.citrix_workspace.version "21.11.0.10" <= 0;
        super.citrix_workspace.overrideAttrs (oldAttrs: rec {
          version = "21.11.0.10";
          #name = "$citrix_workspace-${version}";
          buildInputs = oldAttrs.buildInputs or [ ] ++ [
            (super.runCommand "libunwind-faked" { } ''
              mkdir -p $out/lib
              ln -s ${self.libunwind}/lib/libunwind.so $out/lib/libunwind.so.1
            '')
            self.glib-networking
          ];
          src = super.fetchurl {
            url = "https://downloads.citrix.com/20098/linuxx64-21.11.0.20.tar.gz";
            sha256 = "1595pm5nhw7bjrns7q75ibd1b2kb0w28v699y1gcy7i8p8a5pwqy";
          };
        })
      );

    })
  ];



  #all = super.buildEnv {
  #  # This creates an indirection.
  #  # Nix-env will install this as the only package, creating a layer of symlinks.
  #  # But, installing this directly as the main derivation prevents to add temporary derivations using nix-env
  #  # Basically, we want to keep it. Live with it !
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
        xournal
        wf-recorder
        poppler_utils
        teams
        #kdenlive
        # }}}

        # {{{ Graphical applications
        #firefox /*-bin*/
        thunderbird
        chromium
        libreoffice # Not yet cached...
        gnumeric
        calibre
        gimp #gimp-with-plugins
        slack
        element-desktop
        mozart2
        #(builtins.storePath /nix/store/8i227iqjsaq7g4ddbrav6jn6w2lbxs9l-mozart2-2.0.0-beta.1)
        zim
        skype
        zoom-us
        texmaker
        #typora # error: Newer versions of typora use anti-user encryption and refuse to start.
        inkscape
        yed
        hexchat
        vlc
        guvcview
        krita

        wireshark-qt

        idea.idea-community
        idea.pycharm-community

        #virtualbox
        zotero

        # }}}
        # {{{ Desktop environment
        gnome.gnome_themes_standard # For firefox and thunderbird theming.
        gnome.evince
        gnome.eog
        gnome.nautilus
        gnome.file-roller
        pavucontrol
        keychain
        xclip
        imagemagickBig
        sox
        pdfpc
        #gstreamer
        #gst-plugins-base
        #gst-plugins-good
        #gst-plugins-bad
        #gst-plugins-ugly
        #gst-ffmpeg
        gtkspell3
        gitg
        wget
        networkmanagerapplet

        citrix_workspace_custom

        # support both 32- and 64-bit applications
        wineWowPackages.stable
        # winetricks and other programs depending on wine need to use the same wine version
        (winetricks.override { wine = wineWowPackages.stable; })

        kanshi

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
        gnome3.zenity
        qtikz
        gnome3.gnome-settings-daemon

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
      gitAndTools.hub
      gitAndTools.gh
      ack
      tree
      ripgrep
      fd
      ctags
      file
      zip
      unzip
      jshon
      fzf
      lynx
      screen
      ghostscript # Why is this needed ? conflicts with texlive.
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


      # }}}
      # {{{ Misc
      #((rustChannelOf { channel = "nightly"; date = "2019-02-04"; }).rust.override { extensions = [ "clippy-preview" "rust-src" ]; })
      manpages
      #eid-viewer # does not exist anymore ?
      parallel
      pv
      psmisc # contains `killall`
      dnsutils # contains `dig`
      vcsh # To manage dotfiles
      #tup
      gawk
      biber
      #gnome3.gconf #missinig
      gnumake
      tup
      #(lib.lowPrio remake)
      (lib.lowPrio moreutils)
      pandoc
      woof # file transfer with trivial http server
      #(lib.lowPrio (                      # conflicts wit ghostscript
      #  texlive.combine { 
      #    inherit (texlive) scheme-full;
      #    #inherit (default) auctex;
      #    pkgFilter = pkg: pkg.tlType == "run" || pkg.tlType == "bin" || pkg.pname == "pgf";
      #  }
      #))
      patchelf
      binutils
      gdb
      #mypkgs.EMV-CAP
      #readlinks
      #mypkgs.monitormonitors
      sqlite-interactive
      inotify-tools
      jotta-cli

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
      bazel
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
