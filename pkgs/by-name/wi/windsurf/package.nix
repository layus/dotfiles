{ writeShellApplication, xxd, symlinkJoin, installShellFiles, bats, zsh, runCommand }:

let
  script = writeShellApplication {
    name = "windsurf";
    runtimeInputs = [ xxd ];
    text = builtins.readFile ./windsurf.sh;
  };

  completion = ./. + "/_windsurf";

in
symlinkJoin {
  name = "windsurf-wrapper";
  nativeBuildInputs = [ installShellFiles ];
  paths = [ script ];
  passthru.tests.completion = runCommand "windsurf-completion-tests"
    {
      nativeBuildInputs = [ bats zsh ];
    } ''
    COMPLETION_FILE=${completion} bats ${./test-completion.zsh}
    touch $out
  '';
  postBuild = ''
    installShellCompletion --zsh ${completion}
  '';
}
