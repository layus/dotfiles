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
  xdg.configFile."sway/config".source = lib.mkForce "${pkgs.sway-config}/etc/sway/config";

  nixpkgs.overlays = [
    (self: super: {
      sway-config = super.callPackage ./sway.nix {};
      lockimage = "/missing"; #TODO
    })
    (import ./packages.nix)
  ];

  nixpkgs.config = import ./dotfiles/nixpkgs-config.nix;
  xdg.configFile."nixpkgs/config.nix".text = builtins.readFile ./dotfiles/nixpkgs-config.nix;

  home.packages = with pkgs; [
    all
  ];

  programs.direnv.enable = true;
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

  xdg.configFile."waybar" = {
    source = ./dotfiles/waybar;
    recursive = true;
  };

  home.file.".bash_aliases".source = ./dotfiles/bash_aliases;
  home.file.".bash_aliases.git".source = ./dotfiles/bash_aliases.git;

  programs.termite.enable = true;
  xdg.configFile."termite/config".source = ./dotfiles/termite;

  programs.firefox.enable = true;
  programs.firefox.profiles.default = {
    userChrome = builtins.readFile ./dotfiles/userChrome.css;
  };

  xdg.mime.enable = true;
  xdg.mimeApps.enable = true;
  xdg.configFile."mimeapps.list".source = ./dotfiles/mimeapps.list;

  home.file.".ssh/pubkeys" = {
    source = ./dotfiles/ssh/pubkeys;
    recursive = true;
  };
  home.file.".ssh/id_ecdsa.pub".source = ./dotfiles/ssh/pubkeys/uberwald_ecdsa.pub;

}
