{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # nixpkgs-unstable";

  inputs.homeManager.url = "github:nix-community/home-manager";
  inputs.homeManager.inputs.nixpkgs.follows = "nixpkgs";

  inputs.nixvim.url = "github:nix-community/nixvim";
  inputs.nixvim.inputs.nixpkgs.follows = "nixpkgs";

  inputs.localConfig.url = "path:./local-default";

  inputs.git-hooks.url = "github:cachix/git-hooks.nix";
  inputs.git-hooks.inputs.nixpkgs.follows = "nixpkgs";

  #inputs.dwarffs.url = "github:edolstra/dwarffs";
  #inputs.dwarffs.inputs.nixpkgs.follows = "nixpkgs";
  #inputs.dwarffs.inputs.nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, homeManager, nixpkgs, localConfig, git-hooks, ... }@args:
    let
      lib = nixpkgs.lib;

      # Auto-generate homeConfigurations from home/users/*.nix filenames.
      # Files are named "user@machine.nix" and produce a "user@machine" entry.
      # Additionally, "user@headless.nix" also produces a bare "user" entry
      # (used as fallback when home-manager can't match user@hostname).
      userFiles = builtins.readDir ./home/users;
      homeEntries = lib.concatMapAttrs
        (filename: _:
          let
            stem = lib.removeSuffix ".nix" filename;
            parts = lib.splitString "@" stem;
            user = builtins.elemAt parts 0;
            machine = builtins.elemAt parts 1;
          in
          { "${stem}" = import ./home args user machine; }
          // lib.optionalAttrs (machine == "headless") { "${user}" = import ./home args user machine; }
        )
        userFiles;
    in
    {
      overlays.default = final: prev:
        let
          byNameDir = ./pkgs/by-name;
          # Scan pkgs/by-name/<shard>/<name>/package.nix (nixpkgs convention)
          shards = builtins.readDir byNameDir;
          packagesFromShard = shard: _:
            lib.mapAttrs'
              (name: _: lib.nameValuePair name (final.callPackage (byNameDir + "/${shard}/${name}/package.nix") { }))
              (builtins.readDir (byNameDir + "/${shard}"));
        in
        lib.concatMapAttrs packagesFromShard shards;

      packages.x86_64-linux = {
        nix = nixpkgs.legacyPackages.x86_64-linux.nix;
      };

      nixosConfigurations =
        lib.attrsets.mapAttrs
          (machine: _: import ./nixos args machine)
          (builtins.readDir ./nixos/machines)
      ;

      homeConfigurations = homeEntries;

      checks.x86_64-linux.pre-commit-check = git-hooks.lib.x86_64-linux.run {
        src = self;
        hooks = {
          nixpkgs-fmt.enable = true;
        };
      };

      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        inherit (self.checks.x86_64-linux.pre-commit-check) shellHook;
        buildInputs = self.checks.x86_64-linux.pre-commit-check.enabledPackages;
      };
    };

}
