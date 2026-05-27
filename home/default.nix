{ self, homeManager, localConfig, nixpkgs, lib ? nixpkgs.lib, ... }@args:
name: machine:

homeManager.lib.homeManagerConfiguration {
  modules = [
    (./users + "/${name}@${machine}.nix")
    (localConfig.home-overlay or { })

    # config integrity: capture revision + block activation on dirty builds
    # Note: --override-input makes self.rev absent (lock mismatch), but the
    # git tree may still be clean.  Accept dirtyRev when it lacks "-dirty".
    ({ lib, ... }:
    let
      rev = self.rev or self.dirtyRev or null;
      isClean = rev != null && ! lib.hasSuffix "-dirty" rev;
    in {
      home.file.".config/hm-config-rev" = lib.mkIf isClean {
        text = rev;
      };

      home.sessionVariables.HM_CONFIG_REV = if rev != null then rev else "unknown";

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
