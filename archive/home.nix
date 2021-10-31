{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    htop
    gnome.gnome-calendar
    # {{{ special
    #converted to plugins: obs-wlrobs obs-studio
    xournal
    wf-recorder
    poppler_utils
    teams
    #kdenlive
    # }}}

    # {{{ Graphical applications
    thunderbird
    libreoffice # Not yet cached...
    gnumeric
    gimp #gimp-with-plugins
    slack
    element-desktop
    mozart2
    #(builtins.storePath /nix/store/8i227iqjsaq7g4ddbrav6jn6w2lbxs9l-mozart2-2.0.0-beta.1)
    zim
    skype
    texmaker
    typora
    inkscape
    yed
    hexchat
    vlc
    guvcview
    krita

    aspellDicts.fr
    aspellDicts.en
    wireshark-qt

    idea.idea-community
    idea.pycharm-community

    #virtualbox
    zotero

    # }}}
    # {{{ Desktop environment
    gnome3.gnome_themes_standard        # For firefox and thunderbird theming.
    conky dmenu scrot                  # for i3.
    volumeicon pavucontrol              # for i3.
    networkmanagerapplet
    termite                             # for i3
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

    mypkgs.i3-config
    #mypkgs.sway-config
    #kanshi
    #(sway.override { withBaseWrapper = true; withGtkWrapper = true; })

    # }}}
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
    neovim
    emacs
    #gitFull 
    #(mercurialFull.overrideAttrs (oldAttrs: {
    #  propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or []) ++ [ pythonPackages.simplejson ]; # for mozilla pushtree
    #}))
    subversion            # VCS
    gitAndTools.hub
    gitAndTools.gh
    ack tree ripgrep fd
    ctags
    file
    zip unzip
    jshon
    lynx
    screen tmux
    ghostscript     # Why is this needed ? conflicts with texlive.
                    # => Maybe for converting pdf to text.
                    diffutils colordiff wdiff
                    graphviz
    #nixUnstable
    niv
    ffmpeg
    # fails - diffoscope
    pdfgrep
    rsync borgbackup
    direnv
    bat
    hyperfine
    jq yq
    tmux


    # }}}
    # {{{ Misc
    #((rustChannelOf { channel = "nightly"; date = "2019-02-04"; }).rust.override { extensions = [ "clippy-preview" "rust-src" ]; })
    manpages
    #eid-viewer # does not exist anymore ?
    parallel
    pv
    psmisc                              # contains `killall`
    dnsutils                            # contains `dig`
    vcsh                                # To manage dotfiles
    #tup
    gnuplot
    gawk
    #xorg.xclock
    gnome3.zenity
    gnome3.gnome-settings-daemon
    #gnome3.gconf #missinig
    gnumake
    tup
    #(lib.lowPrio remake)
    (lib.lowPrio moreutils)
    pandoc
    (lib.lowPrio (                      # conflicts wit ghostscript
    texlive.combine { 
      inherit (texlive) scheme-full;
        #inherit (default) auctex;
        pkgFilter = pkg: pkg.tlType == "run" || pkg.tlType == "bin" || pkg.pname == "pgf";
      }
      ))
      qtikz
      biber
      patchelf binutils
      gdb
      mypkgs.EMV-CAP
      readlinks
      mypkgs.monitormonitors
      meld
      sqlite-interactive
      inotify-tools

    # }}}
    # {{{ Admin
    xorg.xrandr arandr autorandr        # display management
    xorg.xev
    htop
    xorg.xkill
    (lib.lowPrio openssl)
    ydotool

    # }}}
    # {{{ Courses
    #dafny 
    #vscode mono # mono explicitly required by VSCode to run dafny
    bazel
    #(if true then (lib.hiPrio gcc6) else gcc)
    #jre
    jdk

    xorg.xclock

    # }}}
    # {{{ Nix internals fixup
    shared-mime-info
    gtk3
    glib.dev
    desktop-file-utils
    texinfo

    # }}}
  ];


  programs.firefox = {
    enable = true;
    profiles = {
      "cg97rd9b.default-1505371850214" = {
        name = "default";
        id = 1;
        isDefault = true;
      };
      "exsu0ne5.dev-edition-default" = {
        name = "dev-edition-default";
        id = 0;
        isDefault = false;
      };
      "c5jxfa51.Blank" = {
        name = "Blank";
        id = 2;
        isDefault = false;
      };
    };
  };

  programs.chromium.enable = true;

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
  };

  programs.home-manager = {
    enable = true;
    path = "/home/gmaudoux/projets/home-manager";
  };

  programs.git = {
    enable = true;
    userName = "Guillaume Maudoux";
    userEmail = "guillaume.maudoux@uclouvain.be";
  };

  wayland.windowManager.sway = {
    enable = true;
  };
  xdg.configFile."sway/config".source = lib.mkForce /home/gmaudoux/.config/sway/config;

  services.kanshi.enable = true;
  xdg.configFile."kanshi/config".source = /home/gmaudoux/.config/kanshi/config;

  #xdg.mimeApps.enable = true; # Not really, it is quite stateful.
}
