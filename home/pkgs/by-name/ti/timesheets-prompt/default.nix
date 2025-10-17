{
  lib,
  python3Packages,
  wrapGAppsHook4,
  gobject-introspection,
  gtk4-layer-shell,
}:

python3Packages.buildPythonPackage rec {
  pname = "timesheets-prompt";
  version = "0.0.1";
  pyproject = false;

  dontUnpack = true;

  nativeBuildInputs = [
    wrapGAppsHook4
    gobject-introspection
  ];

  buildInputs = [
    gtk4-layer-shell
  ];

  dependencies = [ python3Packages.pygobject3 ];

  installPhase = ''
    install -Dm755 "${./${pname}.py}" "$out/bin/${pname}"
  '';

  dontWrapGApps = true;

  preFixup = ''
    makeWrapperArgs+=(
      ''${gappsWrapperArgs[@]}
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ gtk4-layer-shell ]}
    )
  '';
  
  meta = {
    description = "Invasive timesheets prompt";
    maintainers = with lib.maintainers; [ layus ];
    mainProgram = pname;
    platforms = lib.platforms.linux;
  };
}
