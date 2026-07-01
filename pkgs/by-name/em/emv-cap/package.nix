{ lib, python3Packages, fetchFromGitHub }:

python3Packages.buildPythonApplication rec {
  pname = "emv-cap";
  version = "1.6-unstable-2026-03-26";

  src = fetchFromGitHub {
    owner = "doegox";
    repo = "EMV-CAP";
    rev = "ad10a720a327bba52116ec3276b04d2a8811ccf6";
    hash = "sha256-61n4KQLLfIzasW8CoBDC5ENovMiCtdIxy/MbeMFQJoo=";
  };

  # - Upstream ships a `#!/usr/bin/env -S uv run --script` shebang with PEP 723
  #   inline dependencies; under Nix we provide the deps ourselves, so strip
  #   the uv metadata and let buildPythonApplication rewrite the shebang to the
  #   wrapped Python interpreter instead of fetching packages at runtime.
  # - Skip the interactive "type YES to continue" confirmation prompt.
  postPatch = ''
    substituteInPlace EMV-CAP \
      --replace-fail '#!/usr/bin/env -S uv run --script' '#!/usr/bin/env python3' \
      --replace-fail "resp = input('If so, type \'YES\', or anything else to quit:')" "resp = 'YES'"
  '';

  propagatedBuildInputs = with python3Packages; [ pyscard pycryptodome ];
  pyproject = true;
  build-system = with python3Packages; [ setuptools ];

  meta = {
    description = "EMV-CAP calculator";
    homepage = "https://github.com/doegox/EMV-CAP";
    license = lib.licenses.gpl3Plus;
  };
}
