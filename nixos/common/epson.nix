{ pkgs, ... }:
{
  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = [ 
      #pkgs.epson-escpr
      pkgs.epson-escpr2
    ];
    browsing = true;
    defaultShared = true;
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
    publish.userServices = true;
  };

  hardware.sane = {
    enable = true;
    extraBackends = [
      #pkgs.epson-escpr
      pkgs.epson-escpr2
    ];
  };
}
