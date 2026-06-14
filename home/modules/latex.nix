{ config, lib, pkgs, ... }:

{
  home.packages = lib.mkIf config.custom.graphical [
    (lib.lowPrio (
      pkgs.texlive.combine {
        inherit (pkgs.texlive) scheme-full;
        pkgFilter = pkg: pkg.tlType == "run" || pkg.tlType == "bin" || pkg.pname == "pgf";
      }
    ))
  ];
}
