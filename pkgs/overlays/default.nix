# Overrides of existing nixpkgs packages. Composed into flake `overlays.default`
# (see flake.nix) so the patched packages are visible to both NixOS and
# home-manager — and, because this overlay is applied first, to anything built
# with `super.callPackage` later in the overlay chain (e.g. sway-config).
final: prev:

{
  factorio = prev.factorio.overrideAttrs (oldAttrs: rec {
    version = "2.0.32";
    pname = "factorio";
    name = "${pname}-${version}";
    src = prev.requireFile {
      url = "https://dl.factorio.com/releases/factorio_alpha_x64_${version}.tar.xz";
      hash = "sha256:0xrx5snnsln4az47h7vxamh0zgsf8lcrdxm01qh5w0b5svcwmcai";
    };
  });

  systembus-notify = prev.systembus-notify.overrideAttrs (oldAttrs: {
    patches = oldAttrs.patches or [ ] ++ [ ./systembus-notify.patch ];
  });

  # Inline, clickable action buttons drawn beneath notifications.
  mako = prev.mako.overrideAttrs (oldAttrs: {
    patches = oldAttrs.patches or [ ] ++ [ ./inline-action-buttons.patch ];
  });

  slurp = assert builtins.compareVersions "1.3.2" prev.slurp.version <= 0;
    prev.slurp.overrideAttrs (oldAttrs: {
      src = prev.fetchFromGitHub {
        owner = "wisp3rwind";
        repo = "slurp";
        rev = "fixed_aspect_ratio";
        hash = "sha256-9x+6nb+QnBsbndX9GpJYvi1czRkZ9qArLgs4a3gzHhQ=";
      };
    });

  slack = prev.slack.overrideAttrs (oldAttrs: {
    installPhase = final.lib.replaceStrings [ "--suffix PATH" ] [ "--suffix XDG_CURRENT_DESKTOP : GNOME \\\n  --suffix PATH" ] oldAttrs.installPhase;
  });
}
