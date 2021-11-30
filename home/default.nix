{ homeManager, localConfig, nixpkgs, lib ? nixpkgs.lib, ... }@args:
name: machine:

homeManager.lib.homeManagerConfiguration (import (./users + "/${name}@${machine}.nix") // {
  extraModules = lib.optional (localConfig ? home-overlay) localConfig.home-overlay;
})
