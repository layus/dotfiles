{config, pkgs, ...}:
{

  # Add fonts
  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    packages = with pkgs; [
      # Contain a lot of variants
      #bakoma_ttf
      #cm_unicode
      andagii
      anonymousPro
      arkpandora_ttf
      caladea
      cantarell-fonts
      carlito
      clearlyU
      comfortaa
      comic-relief
      corefonts
      crimson
      dejavu_fonts
      gentium
      #google-fonts
      inconsolata # monospaced
      liberation_ttf
      liberation-sans-narrow
      libertine
      libertinus
      mononoki
      montserrat
      norwester-font
      open-sans
      pecita
      powerline-fonts
      roboto
      sampradaya
      source-code-pro
      source-sans-pro
      source-serif-pro
      tai-ahom
      tempora_lgc
      terminus_font
      theano
      ttf_bitstream_vera
      ubuntu_font_family
      #vistafonts
      noto-fonts
      font-awesome
      mplus-outline-fonts.osdnRelease # Switch to githubRelease later when font is fixed
      #nerdfonts
      (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "Hack"]; })
    ];
    fontconfig = {
      defaultFonts = {
        monospace = [ "Ubuntu Mono" ];
        sansSerif = [ "Ubuntu" ];
        serif = [ "Carlito" ];
      };

      /*
      confPackages = let
        workaround = font: pkgs.runCommand "${font.name}-alias" {} ''
          mkdir -p $out/etc/fonts/${pkgs.fontconfig.configVersion}
          ln -s ${font}/etc/fonts/conf.d $out/etc/fonts/${pkgs.fontconfig.configVersion}
        '';
      in with pkgs; [
        (workaround carlito)
      ];
      */
      confPackages = [ pkgs.carlito ];
      # penultimate.enable = true;
    };
  };

  # XXX: Why ?
  environment.systemPackages = with pkgs; [
    corefonts
    carlito
  ];

}
