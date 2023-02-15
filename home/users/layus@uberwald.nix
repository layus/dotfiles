{ config, pkgs, lib, ... }:

{
  home.username = "layus";
  home.homeDirectory = "/home/layus";
  home.stateVersion = "21.11";

  custom.graphical = true;

  programs.helix.enable = true;

  programs.git = {
    userName = "Guillaume Maudoux";
    userEmail = "guillaume.maudoux@tweag.io";
  };

  nixpkgs.config.allowUnfree = true;
  imports = [
    ../profiles/nvim.nix
  ];

  #systemd.user.services = {
  #  jottacloud-daemon = {
  #    Unit = {
  #      Description = "Jottacloud sync daemon";
  #    };
  #    Service = {
  #      ExecStart = "${pkgs.jotta-cli}/bin/jottad stdoutlog datadir .config/jottad";
  #      RestartSec = 300;
  #      Restart = "always";
  #    };
  #    Install = {
  #      WantedBy = [ "default.target" ];
  #    };
  #  };
  #};
}


