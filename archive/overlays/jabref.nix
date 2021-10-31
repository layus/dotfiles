self: super:

{
  jabref = (super.jabref.override {
    jre = self.oraclejre;
    jdk = self.oraclejdk;
  }).overrideAttrs (oldAttrs: rec {
    version = "4.3.1";
    name = "jabref-${version}";

    src = super.fetchurl {
      url = "https://github.com/JabRef/jabref/releases/download/v${version}/JabRef-${version}.jar";
      sha256 = "15f3risav4vlr3jvmrn93qfw54filfxl99h6j3cmj2j3kh3ywljv";
    };

    installPhase = builtins.replaceStrings [ "icons/JabRef-icon-mac" "svg" ] [ "external/JabRef-icon-128" "png" ] oldAttrs.installPhase;
  });
}
