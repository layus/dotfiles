{ homeManager, localConfig, nixpkgs, lib ? nixpkgs.lib, ... }@args:
name: machine:

homeManager.lib.homeManagerConfiguration {
  modules = [
    (./users + "/${name}@${machine}.nix")
    localConfig.home-overlay or { }
  ] ++ import ./modules/modules-list.nix;
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
}
