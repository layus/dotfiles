# define a new module
{ config, lib, ... }:
{
  # that defines extra features for the existing config `environment.etc`
  options.environment.etc = mkOption {
    type = types.attrsOf (
      # by the means of an extra submodule type
      types.submodule (
        { name, config, ... }:
        {
          # where `source` is assigned with normal priority
          config.source = mkIf (config.text != null) (
            let name' = "etc-" + baseNameOf name;
            in pkgs.writeText name' config.text
          );
        }
      )
    );
  };
}
)
