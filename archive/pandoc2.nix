{ mkDerivation, aeson, aeson-pretty, base, base64-bytestring
, binary, blaze-html, blaze-markup, bytestring, Cabal
, case-insensitive, cmark-gfm, containers, criterion, data-default
, deepseq, Diff, directory, doctemplates, executable-path, fetchgit
, file-embed, filepath, Glob, haddock-library, hslua, HTTP, http-client
, http-client-tls, http-types, JuicyPixels, mtl, network
, network-uri, pandoc-types, parsec, process, QuickCheck, random
, safe, scientific, SHA, skylighting, split, stdenv, syb, tagsoup
, tasty, tasty-golden, tasty-hunit, tasty-quickcheck, temporary
, texmath, text, time, unix, unordered-containers, vector, xml
, yaml, zip-archive, zlib
}:
mkDerivation {
  pname = "pandoc";
  version = "2.0.2";
  src = fetchgit {
    url = "https://github.com/jgm/pandoc";
    sha256 = "168l76gi4bdp9dh25mnqchj17iixp9vf9zxpx5dwzj0xwqm9kp7x";
    rev = "51897937cd07a066df656451068ef56d13b4edc4";
  };
  isLibrary = true;
  isExecutable = true;
  enableSeparateDataOutput = true;
  setupHaskellDepends = [ base Cabal ];
  libraryHaskellDepends = [
    aeson aeson-pretty base base64-bytestring binary blaze-html
    blaze-markup bytestring case-insensitive cmark-gfm containers
    data-default deepseq directory doctemplates file-embed filepath Glob
    haddock-library hslua HTTP http-client http-client-tls http-types
    JuicyPixels mtl network network-uri pandoc-types parsec process
    random safe scientific SHA skylighting split syb tagsoup temporary
    texmath text time unix unordered-containers vector xml yaml
    zip-archive zlib
  ];
  executableHaskellDepends = [ base ];
  testHaskellDepends = [
    base bytestring containers Diff directory executable-path filepath
    hslua pandoc-types process QuickCheck tasty tasty-golden
    tasty-hunit tasty-quickcheck temporary text zip-archive
  ];
  benchmarkHaskellDepends = [
    base bytestring containers criterion text time
  ];
  preConfigure = ''
    cat pandoc.cabal
    sed -i -e 's| && <[0-9. ]*||' pandoc.cabal
    cat pandoc.cabal
  '';
  doCheck = false;
  homepage = "http://pandoc.org";
  description = "Conversion between markup formats";
  license = "GPL";
}
