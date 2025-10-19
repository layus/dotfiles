{ config, lib, pkgs, ... }:

{
  home.username = "layus";
  home.homeDirectory = "/home/layus";
  home.stateVersion = "21.11";

  imports = [
    ../profiles/nvim.nix
  ];
}
