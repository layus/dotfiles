{ config, pkgs, lib, ... }:

{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "layus";
  home.homeDirectory = "/home/layus";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "21.11";

  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    userName = "Guillaume Maudoux";
    userEmail = "guillaume.maudoux@tweag.io";
    includes = [ { path = ./gitconfig.inc; } ];
  };

  wayland.windowManager.sway.enable = true;
  wayland.windowManager.sway.wrapperFeatures = {
    base = true; # not too sure.
    gtk = true;
  };
  xdg.configFile."sway/config".source = lib.mkForce "${pkgs.sway-config}/etc/sway/config";

  # Kanshi exists only as a systemd user service.
  # I prefer to start it from sway config, as it ensures a proper restart/reload
  #services.kanshi.enable = true;
  # Kanshi config only works with klatch... Ignore for now
  #xdg.configFile."kanshi" = { source = ./dotfiles/kanshi; recursive = true; };

  nixpkgs.overlays = [
    (self: super: {
      sway-config = super.callPackage ./sway.nix {};
      lockimage = pkgs.runCommand "background.jpg" {} ''
        ${pkgs.imagemagick}/bin/convert ${./dotfiles/background.webp} -resize "3840x2400^" -gravity Center -extent 3840x2400+250 $out
      '';
    })
    (import ./packages.nix)
  ];

  nixpkgs.config = import ./dotfiles/nixpkgs-config.nix;
  xdg.configFile."nixpkgs/config.nix".text = builtins.readFile ./dotfiles/nixpkgs-config.nix;

  home.packages = with pkgs; [
    all
  ];

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  programs.direnv.nix-direnv.enableFlakes = true;

  programs.dircolors.enable = true;
  programs.keychain.enable = true;
  programs.zsh.enable = true;
  home.file.".zshrc".source = ./dotfiles/zshrc;

  programs.neovim.enable = true;
  programs.neovim.extraConfig = builtins.readFile ./dotfiles/vimrc;
  programs.neovim.plugins = with pkgs.vimPlugins; [
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
    nvim-yarp
    #vim-hug-neovim-rpc
    #neocomplcache
    neco-ghc
    editorconfig-vim
    syntastic
    #vim-latex
    rust-vim #rust.vim
    vim-racer
  ];

  xdg.configFile."waybar" = { source = ./dotfiles/waybar; recursive = true; };

  home.file.".bash_aliases".source = ./dotfiles/bash_aliases;
  home.file.".bash_aliases.git".source = ./dotfiles/bash_aliases.git;

  programs.termite.enable = true;
  xdg.configFile."termite/config".source = ./dotfiles/termite;

  programs.firefox = {
    enable = true;
    profiles.default = {
      userChrome = builtins.readFile ./dotfiles/userChrome.css;
    };
    package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
      forceWayland = true;
      extraPolicies = {
        ExtensionSettings = {};
      };
    };
  };

  xdg.mime.enable = true;
  xdg.mimeApps.enable = true;
  xdg.configFile."mimeapps.list".source = ./dotfiles/mimeapps.list;

  programs.ssh.enable = true;
  home.file.".ssh/config".source = ./dotfiles/ssh/config;
  home.file.".ssh/pubkeys" = { source = ./dotfiles/ssh/pubkeys; recursive = true; };
  home.file.".ssh/id_ecdsa.pub".source = ./dotfiles/ssh/pubkeys/uberwald_ecdsa.pub;

  programs.mako.enable = true;
  xdg.configFile."mako/config".source = ./dotfiles/mako;


  xdg.userDirs = let
    home = "$HOME/";
  in {
    enable = true;
    createDirectories = true;
    desktop     = "$HOME";
    documents   = "$HOME/documents";
    download    = "$HOME/downloads";
    music       = "$HOME/documents/music";
    pictures    = "$HOME/images";
    publicShare = "$HOME/documents/public";
    templates   = "$HOME/documents/templates";
    videos      = "$HOME/documents";
    extraConfig = {
      XDG_PROJECTS_DIR = "$HOME/projects";
      XDG_PRINT_SCREEN_DIR = "$HOME/images/captures";
    };
  };

  programs.obs-studio = {
    enable = true;
    plugins = [ pkgs.obs-studio-plugins.wlrobs ];
  };
}
