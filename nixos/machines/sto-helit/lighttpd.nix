{config, pkgs, lib, ...}:

let
  myPhp = pkgs.php.buildEnv {
    extensions = { all, enabled }: with all; enabled ++ [ imagick ];
    extraConfig = ''
      max_execution_time = 30
      post_max_size = 100M
      upload_max_size = 100M
      upload_max_filesize = 20M
      memory_limit = 256M
      cgi.fix_pathinfo = 1
    '';
  };
in {
  systemd.services.phpfpm-lighttpd.serviceConfig.ProtectHome = lib.mkForce false;
  services.phpfpm.pools."lighttpd" = {
    phpPackage = myPhp;
    user = "lighttpd";
    group = "lighttpd";
    settings = {
      "pm" = "dynamic";
      "pm.max_children" = 30;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 10;
      "pm.max_requests" = 500;
      "listen.owner" = "root";
      "listen.group" = "lighttpd";
      "listen.mode" = "0660";
      "slowlog" = "/home/http/mariage/Lychee/slow.log";
      "catch_workers_output" = "yes";
    };
  };

  environment.systemPackages = [ myPhp myPhp.packages.composer ];

  #systemd.services.lighttpd.path = [ pkgs.imagemagick ];

  services.lighttpd = {
    enable = true;
    document-root = "/nonexistent" ; # Serve the current directory

    mod_status = true;
    enableModules = [
      "mod_auth"  # Simple auth scheme
      "mod_authn_file"
      "mod_fastcgi"
      "mod_openssl"
      "mod_access"
      "mod_alias"
      "mod_rewrite"
    ];
    extraConfig = ''
      #dir-listing.activate = "enable"

      # Auth
      # Done in enableModules: server.modules += ( "mod_auth" )
      #auth.debug = 2
      auth.backend = "plain"
      auth.backend.plain.userfile = "/etc/lighttpd/httppasswd"
      auth.require = (
        "/souad-et-antoine" => (
          "method" => "basic",
          "realm" => "Il faut un mot de passe.",
          "require" => "user=souad"
        ),

        "/mariage" => (
          "method" => "basic",
          "realm" => "Il faut un mot de passe.",
          "require" => "user=marie"
        )
      )

      #mimetype.assign += (
      #  # Web
      #  #".html" => "text/html",
      #  #".htm" => "text/html",
      #  #".txt" => "text/plain",
      #  #".css" => "text/css",
      #  #".js" => "application/x-javascript",
      #  # Pictures
      #  #".jpg" => "image/jpeg",
      #  #".jpeg" => "image/jpeg",
      #  #".gif" => "image/gif",
      #  #".png" => "image/png",
      #  # Videos
      #  #".mp4" => "video/mp4",
      #  #".webm" => "video/webm",
      #  #".ogv" => "video/ogg",
      #  # Default
      #  #"" => "application/octet-stream"
      #)

      index-file.names += ( "index.php", "index.html" )

      $HTTP["url"] =~ "^/mariage/Lychee" {
        url.access-deny = ("")
      }

      $HTTP["host"] == "marie-guillaume.maudoux.be" {
        server.document-root = "/home/http/"

        url.rewrite-if-no-file = ( "^/(.*)$" => "/mariage/photos/index.php?/$1" )

        $HTTP["url"] =~ "^/mariage/photos" {
          debug.log-request-header = "enable"
          debug.log-file-not-found = "enable"
          debug.log-condition-handling = "enable"
          debug.log-request-header-on-error = "enable"
          debug.log-request-handling = "enable"
          debug.log-state-handling = "enable"
          debug.log-response-header = "enable"

          alias.url = ()
          url.redirect = ()
          url.rewrite-if-not-file = (
            "^/(css|img|js)/.*\.(jpg|jpeg|gif|png|swf|avi|mpg|mpeg|mp3|flv|ico|css|js)$" => "$0",
            "^/(favicon\.ico|robots\.txt|sitemap\.xml)$" => "$0",
            "^/[^\?]*(\?.*)?$" => "index.php/$1"
          )


          fastcgi.debug = 1
          fastcgi.server = ( ".php" =>
            ((
              "socket" => "${config.services.phpfpm.pools.lighttpd.socket}",
              "min-procs" => 2,
              "max-procs" => 4,
              "idle-timeout" => 30,
              "broken-scriptfilename" => "enable",
              "check-local" => "disable"
            ))
          )
        }
      }

      $HTTP["host"] == "maudoux.be" {
        server.document-root = "/home/http"

        $HTTP["url"] =~ "^/51a12811-cf4a-46ba-ab71-d769a0f38676($|/)" {
          dir-listing.activate = "enable"
        }
      }

      #$HTTP["host"] == "sto-lat.no-ip.org" {
      #  $HTTP["url"] =~ "^/souad-et-antoine" {
      #    server.document-root = "/home/http/"
      #  }
      #}


      # Let's encrypt

      $HTTP["url"] =~ "^/.well-known" {
        server.document-root = "${config.security.acme.certs.maudoux.webroot}"
      }

      $SERVER["socket"] == ":443" {
        protocol     = "https://"
        ssl.engine   = "enable"
        ssl.disable-client-renegotiation = "enable"

        # pemfile is cert+privkey, ca-file is the intermediate chain in one file
        ssl.pemfile             = "${config.security.acme.certs.maudoux.webroot}/full.pem"
        ssl.ca-file             = "${config.security.acme.certs.maudoux.webroot}/fullchain.pem"
        # for DH/DHE ciphers, dhparam should be >= 2048-bit
        ssl.dh-file            = "/etc/lighttpd/certificates/dhparam.pem"
        # ECDH/ECDHE ciphers curve strength (see `openssl ecparam -list_curves`)
        ssl.ec-curve            = "secp384r1"
        # Compression is by default off at compile-time, but use if needed
        #ssl.use-compression     = "disable"

        # Environment flag for HTTPS enabled
        setenv.add-environment = (
            "HTTPS" => "on"
        )

        # intermediate configuration, tweak to your needs
        ssl.use-sslv2 = "disable"
        ssl.use-sslv3 = "disable"
        ssl.honor-cipher-order    = "enable"
        ssl.cipher-list           = "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:ECDHE-RSA-DES-CBC3-SHA:ECDHE-ECDSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA"
      }

    ''; # services.lighttpd.extraConfig
  }; # services.lighttpd
}
