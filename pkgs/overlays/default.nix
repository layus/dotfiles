# Overrides of existing nixpkgs packages. Composed into flake `overlays.default`
# (see flake.nix) so the patched packages are visible to both NixOS and
# home-manager — and, because this overlay is applied first, to anything built
# with `super.callPackage` later in the overlay chain (e.g. sway-config).
final: prev:

{
  # afdko 5.0.1 (nixos-unstable, 2026-06) removed the `afdko._deprecated`
  # module, which breaks both `otfautohint` and `cffsubr` — so cantarell-fonts
  # fails to build its variable font. Until upstream nixpkgs fixes the
  # toolchain, take the prebuilt font from a pinned known-good nixpkgs (the
  # output is just a font, identical regardless of which tree built it, and is
  # in the binary cache). Drop this override once cantarell builds on unstable.
  cantarell-fonts =
    let
      goodPkgs = import
        (builtins.fetchTarball {
          url = "https://github.com/NixOS/nixpkgs/archive/9ae611a455b90cf061d8f332b977e387bda8e1ca.tar.gz";
          sha256 = "sha256-md8WlXOlfnIeHeOScMTTHFyf2d6iaTwPl2apR5EQ3P4=";
        })
        { system = prev.stdenv.hostPlatform.system; };
    in
    goodPkgs.cantarell-fonts;

  # Python 3.11.17+/3.12.15+ reject server_hostname in server mode, which breaks
  # anyio's test_tls_connectable (https://github.com/NixOS/nixpkgs/issues/570271).
  # Upstream fix: agronholm/anyio@818e4ac4. Drop once anyio ships a release with it.
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      anyio = assert final.lib.versionAtLeast "4.15.1" python-prev.anyio.version;
        python-prev.anyio.overridePythonAttrs (oldAttrs: {
          disabledTests = oldAttrs.disabledTests or [ ]
            ++ final.lib.optionals (python-final.pythonOlder "3.13") [ "test_tls_connectable" ];
        });
    })
  ];

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

  # Sticky monitor borders: a `seat * { edge_resistance <px> }` option that
  # makes the pointer pause at an output edge until pushed through, so small
  # targets along shared monitor edges are easier to hit.
  sway-unwrapped = prev.sway-unwrapped.overrideAttrs (oldAttrs: {
    patches = oldAttrs.patches or [ ] ++ [ ./sway-sticky-monitor-borders.patch ];
  });

  # Clicking a sway workspace button switches with `workspace number N`, which
  # picks the wrong one when names share a number ("1" on eDP-1, "1'" on DP-3)
  # and bounces back via workspace_auto_back_and_forth. Switch by (quoted)
  # name instead: https://github.com/Alexays/Waybar/pull/5514
  # Drop once a waybar release (> 0.16.0) includes it.
  waybar = assert final.lib.versionAtLeast "0.16.0" prev.waybar.version;
    prev.waybar.overrideAttrs (oldAttrs: {
      patches = oldAttrs.patches or [ ] ++ [
        (final.fetchpatch {
          name = "waybar-sway-workspaces-switch-by-quoted-name.patch";
          url = "https://github.com/Alexays/Waybar/commit/6b03add88dc93757077ba79cc10335bed6d12bd6.patch";
          hash = "sha256-+Rv4z1SvAssA8J293sGsrPftc8sU9ma8ymI+C4qSn78=";
        })
      ];
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
