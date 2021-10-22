{ config, pkgs, ... }:
{

  # enable davfs2
  users.groups .davfs2.gid   = config.ids.gids.davfs2;
  users.users  .davfs2.uid   = config.ids.uids.davfs2;
  users.users  .davfs2.group = "davfs2";

  environment.systemPackages = [ pkgs.davfs2 ];

  # enable dav @ gvfs
  services.gvfs.enable = true;

  security.pki.certificateFiles = [
    # openssl needs a full chain.
    ./terena.crt
    ./uclouvain.crt
    ./alfresco.uclouvain.crt
  ];

  security.wrappers."mount.davfs" = {
    setuid = true;
    owner = "root";
    group = "root";
    source = "${pkgs.davfs2}/bin/mount.davfs";
  };

}

