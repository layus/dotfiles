self: super:
{
  sourcetrail = super.sourcetrail.overrideAttrs (oldAttrs: {
    src = super.fetchurl {
      #url = "https://github.com/CoatiSoftware/Sourcetrail/releases/download/2020.2.43/Sourcetrail_2020_2_43_Linux_64bit.tar.gz";
      url = "https://github.com/CoatiSoftware/Sourcetrail/releases/download/2019.4.61/Sourcetrail_2019_4_61_Linux_64bit.tar.gz";
      #sha256 = "0zgh0rm39cbhvg2sk5rsxswsjhpsv26rf7vn17x1j5yv6jpxyhnh";
      sha256 = "1vr73aw6yqjhdlviq08zvqh96hw9iw3y058snsgcy7977rgrk81v";
    };

    preInstall = "touch EULA.txt";
  });

  #sourcetrail = super.stdenv.mkDerivation {
  #  pname = "sourcetrail";
  #  version = "2020-2-43";

  #  src = super.fetchurl {
  #    url = "https://github.com/CoatiSoftware/Sourcetrail/archive/2020.2.43.tar.gz";
  #    sha256 = "14lvzrr409drmvnls1kikbdyyqc2596wf4ls0wc8kjskzlj4bgqr";
  #  };

  #  #src = super.fetchurl {
  #  #  url = "https://github.com/CoatiSoftware/Sourcetrail/releases/download/2020.2.43/Sourcetrail_2020_2_43_Linux_64bit.tar.gz";
  #  #  sha256 = "0zgh0rm39cbhvg2sk5rsxswsjhpsv26rf7vn17x1j5yv6jpxyhnh";
  #  #};

  #  nativeBuildInputs = with self; [ qt5.wrapQtAppsHook cmake ];
  #  buildInputs = with self; [ qt5.qtbase boost llvm llvmPackages.clang-unwrapped jdk maven ];

  #  cmakeFlags = [
  #    "-DCMAKE_BUILD_TYPE=Release"
  #    "-DBoost_USE_STATIC_LIBS=OFF" 
  #    "-DBUILD_CXX_LANGUAGE_PACKAGE=ON"
  #    "-DBUILD_JAVA_LANGUAGE_PACKAGE=ON"
  #    "-DBUILD_PYTHON_LANGUAGE_PACKAGE=ON"
  #  ];

  #  enableParallelBuilding = true;
  #};
}
