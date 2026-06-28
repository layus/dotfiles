{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage {
  pname = "readlinks";
  version = "0.1.0-unstable-2026-06-28";

  src = fetchFromGitHub {
    owner = "layus";
    repo = "readlinks";
    rev = "033210ceef409e6f6b88aff905ea4b6005c14cf7";
    hash = "sha256-a57xm1pFuRRab7viY3KAFYrNzo8KPt5QXwzV1KUfJE8=";
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
