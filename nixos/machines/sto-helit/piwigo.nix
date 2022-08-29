self: super:

{
  piwigo = super.stdenv.mkDerivation rec {
    pname = "piwigo";
    version = "2.10.2";

    src = super.fetchurl {
      name = "${pname}-${version}.zip";
      url = "https://piwigo.org/download/dlcounter.php?code=${version}";
      sha256 = "1zrr578n4grg8cfj7n56zj8aflh8ybb7ikq8w9c816wxvbkmvrqd";
    };

    nativeBuildInputs = [ self.unzip ];

    preUnpack = ''
      mkdir $out
      cd $out
    '';

    meta = with super.lib; {
      description = "Photo gallery software for the web. Designed for organisations, teams and individuals.";
      homepage = "https://piwigo.org/";
      maintainers = with maintainers; [ layus ];
      license = licenses.gpl2;
    };
  };
}
