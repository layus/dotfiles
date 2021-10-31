self: super:

{
  gpx-viewer = super.gpx-viewer.overrideAttrs (oldAttrs: {
    nativeBuildInputs = with self; [
      intltool pkgconfig
      #shared-mime-info # For update-mime-database
      #desktop-file-utils # For update-desktop-database
      wrapGAppsHook # Fix error: GLib-GIO-ERROR **: No GSettings schemas are installed on the system
    ];

    configureFlags = (oldAttrs.configureFlags or []) ++ ["--disable-database-updates"];
    #postConfigure = ''
    #  sed -i Makefile \
    #    -e 's/^install-data-hook: .*/install-data-hook:/'
    #'';
  });
}
