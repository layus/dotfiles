{ lib, config, ... }:
{
  options.custom = {
    graphical = lib.mkEnableOption "graphical applications and config";
  };
}
