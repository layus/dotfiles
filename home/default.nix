{ self, homeManager, localConfig, nixpkgs, lib ? nixpkgs.lib, ... }@args:
name: machine:

homeManager.lib.homeManagerConfiguration {
  modules = [
    (./users + "/${name}@${machine}.nix")
    (localConfig.home-overlay or { })

    # config integrity: capture revision + block activation on dirty builds
    ({ lib, ... }: {
      home.file.".config/hm-config-rev" = lib.mkIf (self ? rev) {
        text = self.rev;
      };

      home.sessionVariables.HM_CONFIG_REV = self.rev or self.dirtyRev or "unknown";

      home.activation.requireCleanConfig = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        if [ ! -f "$newGenPath/home-files/.config/hm-config-rev" ]; then
          echo "ERROR: Refusing to activate — HM config was built from a dirty tree."
          echo "       Commit your changes and rebuild."
          exit 1
        fi
      '';
    })
  ] ++ import ./modules/modules-list.nix;
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
}
