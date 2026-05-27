{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage {
  pname = "readlinks";
  version = "0.1.0-unstable-2019-04-14";

  src = fetchFromGitHub {
    owner = "layus";
    repo = "readlinks";
    rev = "74a611397ea87fbf164895efd6665b585b6e4a2a";
    hash = "sha256-LRbiUr1HlNmVpTfZFvIyiygl3Gd7U8GiwLb/sJkodhE=";
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
