{ python3Packages}:

python3Packages.buildPythonApplication rec {
  name = "readlinks";

  script = ./readlinks ;
  phases = [ "buildPhase" "fixupPhase" ];

  buildPhase = ''
    mkdir -p $out/bin
    cp $script $out/bin/${name}
  '';
}
