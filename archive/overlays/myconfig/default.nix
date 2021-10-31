self: super:

with self;

let
  callPackage = self.lib.callPackageWith (self // mypkgs);
  mypkgs = {
    monitormonitors = callPackage ./scripts/monitormonitors { };
    readlinks = callPackage ./scripts/readlinks { };
    blackout = "${pkgs.i3lock}/bin/i3lock -t -i ${./wall.png}";
    #blackout = callPackage ./scripts/blackout {};

    i3-config = callPackage ./dotfiles/i3/config {
      urxvt = rxvt_unicode-with-plugins;
      inherit (xorg) xbacklight xsetroot;
    };

    lockimage = ./wall.png;
    sway-config = callPackage ./dotfiles/sway/config { };

    EMV-CAP = callPackage ./applications/EMV-CAP { };
  };
in {
  inherit mypkgs;
}
