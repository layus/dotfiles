{ config, lib, ... }:
{
  options.custom.profiles = lib.mkOption {
    type = lib.types.list;
    name = "List of profiles to activate";
    default = [];
  };

  config.imports = builtins.map (p: "${../profiles}/${p}.nix") config.custom.profiles;
}
