{ self, nixpkgs, localConfig, ... }@args:
name:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = args // { inherit name; };
  modules = [
    (./machines + "/${name}/configuration.nix")
    (localConfig.nixos-overlay or {})
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
    # Note: --override-input makes self.rev absent (lock mismatch), but the
    # git tree may still be clean.  Accept dirtyRev when it lacks "-dirty".
    ({ lib, ... }:
    let
      rev = self.rev or self.dirtyRev or null;
      isClean = rev != null && ! lib.hasSuffix "-dirty" rev;
    in {
      system.configurationRevision = if rev != null then rev else "unknown";

      environment.etc."nixos-source".source = self.outPath;

      environment.etc."nixos-config-rev" = lib.mkIf isClean {
        text = rev;
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
