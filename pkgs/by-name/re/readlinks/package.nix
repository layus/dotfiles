{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage {
  pname = "readlinks";
  version = "0.1.0-unstable-2026-09-11";

  src = fetchFromGitHub {
    owner = "layus";
    repo = "readlinks";
    rev = "651ebfd6d9140f17a90c8fcc619fbc7ca97f06c1";
    hash = "sha256-FG2X3LaMPuqmt1LDi8iuQgGiF5Le4e6o78moG65tIFs=";
  };

  cargoLock.lockFile = ./Cargo.lock;

  postPatch = ''
    cp ${./Cargo.lock} Cargo.lock
  '';

  doCheck = false;

  meta = {
    description = "The pedantic symlink resolver";
    homepage = "https://github.com/layus/readlinks";
    license = lib.licenses.mit;
    mainProgram = "readlinks";
  };
}
