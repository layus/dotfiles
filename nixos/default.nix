{ nixpkgs, ... }:
name:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    (./machines + "/${name}/configuration.nix")
    (./machines + "/${name}/hardware-configuration.nix")
  ];

}
