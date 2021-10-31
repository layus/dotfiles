{ python2Packages }:

python2Packages.buildPythonApplication rec {
  name = "EMV-CAP-${version}";
  version = "1.5";

  src = ./EMVCAP-1.5 ;

  propagatedBuildInputs = with python2Packages; [ pyscard pycrypto ];
}

