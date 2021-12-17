{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.homeManager.url = "github:nix-community/home-manager";
  inputs.homeManager.inputs.nixpkgs.follows = "nixpkgs";

  inputs.localConfig.url = "/home/layus/.config/nixpkgs/local";
  inputs.localConfig.inputs.nixpkgs.follows = "nixpkgs";

  #inputs.dwarffs.url = "github:edolstra/dwarffs";
  #inputs.dwarffs.inputs.nixpkgs.follows = "nixpkgs";
  #inputs.dwarffs.inputs.nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, homeManager, nixpkgs, localConfig, ... }@args: {
    nixosConfigurations =
      nixpkgs.lib.attrsets.mapAttrs
        (machine: _: import ./nixos args machine)
        (builtins.readDir ./nixos/machines)
        ;

    homeConfigurations = {
      "layus@uberwald"     = import ./home args "layus" "uberwald";
      "layus@ankh-morpork" = import ./home args "layus" "ankh-morpork";
      "layus@sto-helit"    = import ./home args "layus" "sto-helit";
      "gmaudoux@klatch"    = import ./home args "gmaudoux" "klatch";
      "gmaudoux"           = import ./home args "gmaudoux" "headless";
    };
  };

}
