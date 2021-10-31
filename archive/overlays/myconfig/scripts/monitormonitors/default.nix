{ python3Packages, autorandr }:

python3Packages.buildPythonApplication rec {
  name = "monitormonitors";

  script = ./monitormonitors ;
  phases = [ "buildPhase" "fixupPhase" ];

  propagatedBuildInputs = with python3Packages; [ pyudev ];

  buildPhase = ''
    mkdir -p $out/bin
    cp $script $out/bin/${name}
    substituteInPlace $out/bin/${name} --replace "'/usr/bin/env', 'autorandr'" "'${autorandr}/bin/autorandr'"
  '';
}
