self: super:
{
  factorio = super.factorio.overrideAttrs (oldAttrs: rec {
    version = "1.1.25";
    name = "factorio-${version}";
    src = super.fetchurl {
      url = null;
      name = "factorio_alpha_x64-${version}.tar.xz";
      sha256 = "1xz03xr144grf5pa194j8pvyniiw77lsidkl32wha9x85fln5jhi";
    };
  });

}

