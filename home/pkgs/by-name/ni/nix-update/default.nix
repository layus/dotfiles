{
  lib,
  stdenv,
  python3,
  makeWrapper,
  installShellFiles,
  coreutils,
  git,
  jq,
  nix,
  hostname,
  flakeDir ? null,
}:

stdenv.mkDerivation rec {
  pname = "nix-update";
  version = "0.2.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper installShellFiles ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src/nix-update.py" "$out/libexec/nix-update.py"
    makeWrapper ${python3}/bin/python3 "$out/bin/nix-update" \
      --add-flags "$out/libexec/nix-update.py" \
      --prefix PATH : ${lib.makeBinPath [ coreutils git jq nix hostname ]} \
      ${lib.optionalString (flakeDir != null) "--add-flags '--flake-dir ${flakeDir}'"}

    installShellCompletion --zsh "$src/_nix-update"

    runHook postInstall
  '';

  meta = {
    description = "Build and apply NixOS/Home Manager updates from prebuilt results";
    mainProgram = "nix-update";
    platforms = lib.platforms.linux;
  };
}
