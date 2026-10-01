{ config, lib, pkgs, ... }:

{
  home.packages = lib.mkIf config.custom.graphical [
    (lib.lowPrio (
      # scheme-full without docs/sources, but with pgf docs.
      pkgs.texliveFull.withPackages (ps: [ ps.pgf.texdoc ])
    ))
  ];
}
