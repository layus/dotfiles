{ config, lib, pkgs, ... }:

{

  options.custom = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
  };

  config.custom.ssh.pubkeys = lib.mapAttrs
    (k: v: builtins.readFile (../../home/dotfiles/ssh/pubkeys + "/${k}"))
    (builtins.readDir ../../home/dotfiles/ssh/pubkeys);
}


