{
  pkgs ? import <nixpkgs> {}
, python3Packages ? pkgs.python3Packages
, fetchFromGitHub ? pkgs.fetchFromGitHub
}:

python3Packages.buildPythonApplication rec {
  name = "EMV-CAP-${version}";
  version = "1.5";

  src = fetchFromGitHub {
    owner = "doegox";
    repo = "EMV-CAP";
    rev = "master";
    hash = "sha256-K6uLrkkoWZVByB8toclHRYnVf79dyvMQPQOvDgFvcHo=";
  };

  propagatedBuildInputs = with python3Packages; [ pyscard pycrypto ];
}

