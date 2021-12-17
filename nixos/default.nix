{ nixpkgs, ... }:
name:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    (./machines + "/${name}/configuration.nix")
    #(./machines + "/${name}/hardware-configuration.nix")
    #dwarffs.nixosModules.dwarffs

    # pin NIX_PATH and flake registry
    {
      nix.nixPath = [
        "nixpkgs=${nixpkgs}"
      ];
      nix.registry.nixpkgs.flake = nixpkgs;
    }
  ];

}
