
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.homeManager.url = "github:nix-community/home-manager";
  inputs.homeManager.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, homeManager, nixpkgs }@args: {
    nixosConfigurations = {
      uberwald     = import ./nixos args "uberwald";
      klatch       = import ./nixos args "klatch";
      ankh-morpork = import ./nixos args "ankh-morpork";
      sto-helit    = import ./nixos args "sto-helit";
    };

    homeConfigurations = {
      "layus@uberwald"     = import ./home args "layus" "uberwald";
      "layus@ankh-morpork" = import ./home args "layus" "ankh-morpork";
      "layus@sto-helit"    = import ./home args "layus" "sto-helit";
      "gmaudoux@klatch"    = import ./home args "gmaudoux" "klatch";
    };
  };

}
