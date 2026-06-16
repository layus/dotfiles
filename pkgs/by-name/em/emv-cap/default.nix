{ lib, python3Packages, fetchFromGitHub }:

python3Packages.buildPythonApplication rec {
  pname = "emv-cap";
  version = "1.6";

  src = fetchFromGitHub {
    owner = "doegox";
    repo = "EMV-CAP";
    # rev = master @ v1.6 (untagged)
    # title = Fix setup.py: license, requirements & bump version
    rev = "d28dbdd77b57fe2489d0f3d452a5b716a0852949";
    hash = "sha256-K6uLrkkoWZVByB8toclHRYnVf79dyvMQPQOvDgFvcHo=";
  };

  propagatedBuildInputs = with python3Packages; [ pyscard pycrypto ];
  pyproject = true;
  build-system = with python3Packages; [ setuptools ];

  meta = {
    description = "EMV-CAP calculator";
    homepage = "https://github.com/doegox/EMV-CAP";
    license = lib.licenses.gpl2Only;
  };
}
