{ lib, config, ... }:
{
  options.custom = {
    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Machine hostname for this home-manager configuration.";
    };
    graphical = lib.mkEnableOption "graphical applications and config";
  };
}
