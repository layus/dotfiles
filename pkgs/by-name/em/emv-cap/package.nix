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

  # The T0_protocol/T1_protocol constants are class attributes of
  # smartcard.CardConnection.CardConnection, but MyConnect() returns a
  # CardConnectionDecorator which does not re-export them, so accessing them
  # via the connection object raises AttributeError. Reference the class
  # directly instead. (getProtocol() is an instance method and is forwarded
  # by the decorator, so it stays as-is.)
  postPatch = ''
    substituteInPlace EMV-CAP \
      --replace-fail 'import smartcard' 'import smartcard; from smartcard.CardConnection import CardConnection' \
      --replace-fail 'connection.getProtocol() == connection.T0_protocol' 'connection.getProtocol() == CardConnection.T0_protocol' \
      --replace-fail 'connection.getProtocol() == connection.T1_protocol' 'connection.getProtocol() == CardConnection.T1_protocol'
  '';

  propagatedBuildInputs = with python3Packages; [ pyscard pycrypto ];
  pyproject = true;
  build-system = with python3Packages; [ setuptools ];

  meta = {
    description = "EMV-CAP calculator";
    homepage = "https://github.com/doegox/EMV-CAP";
    license = lib.licenses.gpl2Only;
  };
}
