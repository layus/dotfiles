{ self, nixpkgs, localConfig, ... }@args:
name:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = args // { inherit name; };
  modules = [
    (./machines + "/${name}/configuration.nix")
    (localConfig.nixos-overlay or { })
    #(./machines + "/${name}/hardware-configuration.nix")
    #dwarffs.nixosModules.dwarffs

    # pin NIX_PATH and flake registry
    {
      nix.nixPath = [
        "nixpkgs=${nixpkgs}"
      ];
      nix.registry.nixpkgs.flake = nixpkgs;
    }

    # config integrity: capture revision + enforce clean builds
    # self.rev is present when the tree + lock are clean.  --override-input
    # drops it, but the wrapper writes the verified rev into .verified-rev
    # before building (and truncates it after).  We trust either source.
    ({ lib, ... }:
      let
        verifiedRev = lib.strings.trim (builtins.readFile (self.outPath + "/.verified-rev"));
        rev =
          if self ? rev then self.rev
          else if verifiedRev != "" then verifiedRev
          else null;
      in
      {
        system.configurationRevision = if rev != null then rev else "unknown";

        environment.etc."nixos-source".source = self.outPath;

        environment.etc."nixos-config-rev" = lib.mkIf (rev != null) {
          text = rev;
        };

        system.activationScripts.requireCleanConfig = ''
          if [ ! -e /run/current-system ] || [ "''${NIXOS_ACTION:-}" = "dry-activate" ]; then
            # Allow first boot and dry-activate
            :
          elif [ ! -f "$systemConfig/etc/nixos-config-rev" ]; then
            echo "ERROR: Refusing to activate — NixOS config was built from a dirty tree."
            echo "       Use nix-update or ./rebuild to build from a clean tree."
            exit 1
          fi
        '';
      })
  ];
}
