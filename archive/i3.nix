
import ./config {
  inherit (pkgs)
    volumeicom
    udiskie
    nm-applet
    redshift
    systemd
    ;

  inherit (pkgs.xorg)
    xbacklight
    ;
    
  blackout = "";
}


