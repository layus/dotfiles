# config integrity: capture revision + enforce clean builds
# self.rev is present when the tree + lock are clean.  --override-input
# drops it, but the wrapper writes the verified rev into .verified-rev
# before building (and truncates it after).  We trust either source.
{ lib, self, ... }:
let
  verifiedRev = lib.strings.trim (builtins.readFile (self.outPath + "/.verified-rev"));
  rev =
    if self ? rev then self.rev                    # nix-verified clean tree
    else if verifiedRev != "" then verifiedRev     # wrapper-verified
    else null;
in {
  home.file.".config/hm-source" = {
    source = self.outPath;
    recursive = true;
  };

  home.file.".config/hm-config-rev" = lib.mkIf (rev != null) {
    text = rev;
  };

  home.sessionVariables.HM_CONFIG_REV = if rev != null then rev else "unknown";

  home.activation.requireCleanConfig = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    if [ ! -f "$newGenPath/home-files/.config/hm-config-rev" ]; then
      echo "ERROR: Refusing to activate — HM config was built from a dirty tree."
      echo "       Use nix-update or ./rebuild to build from a clean tree."
      exit 1
    fi
  '';
}
