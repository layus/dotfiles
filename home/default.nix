{ homeManager, localConfig, nixpkgs, lib ? nixpkgs.lib, ... }@args:
name: machine:

let
  getConfig = import (./users + "/${name}@${machine}.nix");
  config = getConfig {config = null; pkgs = null; lib = null;};
in
  homeManager.lib.homeManagerConfiguration {
    configuration = getConfig;
    system = "x86_64-linux";
    inherit (config.home) username homeDirectory stateVersion;
    extraModules = (import ./modules/modules-list.nix) ++ [ localConfig.home-overlay or {} ];
  }
