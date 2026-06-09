{ self, homeManager, localConfig, nixpkgs, nixvim, lib ? nixpkgs.lib, ... }@args:
name: machine:

homeManager.lib.homeManagerConfiguration {
  extraSpecialArgs = { inherit self; };
  modules = [
    nixvim.homeModules.nixvim
    (./users + "/${name}@${machine}.nix")
    (localConfig.home-overlay or { })
    { custom.hostname = machine; }
  ] ++ import ./modules/modules-list.nix;
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
}
