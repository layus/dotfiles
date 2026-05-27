{ self, nixpkgs, ... }@args:
name:

let
  localNixos = ../local/local-nixos.nix;
in
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = args // { inherit name; };
  modules = [
    (./machines + "/${name}/configuration.nix")
  ] ++ nixpkgs.lib.optional (builtins.pathExists localNixos) localNixos ++ [
    #(./machines + "/${name}/hardware-configuration.nix")
    #dwarffs.nixosModules.dwarffs

    # pin NIX_PATH and flake registry
    {
      nix.nixPath = [
        "nixpkgs=${nixpkgs}"
      ];
      nix.registry.nixpkgs.flake = nixpkgs;
    }

    # config integrity: capture revision + block activation on dirty builds
    ({ lib, ... }: {
      system.configurationRevision = self.rev or self.dirtyRev or "unknown";

      environment.etc."nixos-source".source = self.outPath;

      environment.etc."nixos-config-rev" = lib.mkIf (self ? rev) {
        text = self.rev;
      };

      system.activationScripts.requireCleanConfig = ''
        if [ ! -e /run/current-system ] || [ "''${NIXOS_ACTION:-}" = "dry-activate" ]; then
          # Allow first boot and dry-activate
          :
        elif [ ! -f "$systemConfig/etc/nixos-config-rev" ]; then
          echo "ERROR: Refusing to activate — configuration was built from a dirty tree."
          echo "       Commit your changes and rebuild."
          exit 1
        fi
      '';
    })
  ];
}
