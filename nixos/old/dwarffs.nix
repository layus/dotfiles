{ config, pkgs, lib, ... }:

let
  # <dwarffs> / <dwarffs/flake.nix> also an option if you add it to NIX_PATH
  src = builtins.fetchGit {
    url = "http://github.com/edolstra/dwarffs";
  };

  dwarffs =
    { __toString = _: "${src}"; } //
    (import "${src}/flake.nix").outputs {
      self = dwarffs;
      nixpkgs = pkgs;
      nix = pkgs.nix;
    };
in

{
  imports = [
    # ...
    dwarffs.nixosModules.dwarffs
  ];

  # ...
}
