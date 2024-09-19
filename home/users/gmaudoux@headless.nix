{ config, lib, pkgs, ... }:

{
  home.username = "gmaudoux";
  home.homeDirectory = "/home/gmaudoux";
  home.stateVersion = "21.11";

  imports = [
    ../profiles/nvim.nix
  ];
}
