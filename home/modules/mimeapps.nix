# MIME type associations
{ lib, ... }:

{
  xdg.mime.enable = true;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/pdf" = "org.gnome.Evince.desktop";
      "application/rss+xml" = "thunderbird.desktop";
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "writer.desktop";
      "application/x-extension-htm" = "firefox.desktop";
      "application/x-extension-html" = "firefox.desktop";
      "application/x-extension-ics" = "thunderbird.desktop";
      "application/x-extension-rss" = "thunderbird.desktop";
      "application/x-extension-shtml" = "firefox.desktop";
      "application/x-extension-xht" = "firefox.desktop";
      "application/x-extension-xhtml" = "firefox.desktop";
      "application/xhtml+xml" = "firefox.desktop";
      "image/jpeg" = "org.gnome.eog.desktop";
      "image/svg+xml" = "eog.desktop";
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "message/rfc822" = "thunderbird.desktop";
      "text/calendar" = "thunderbird.desktop";
      "text/html" = "firefox.desktop";
      "text/plain" = "org.gnome.gedit.desktop";
      "x-schema-handler/msteams" = "teams.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/chrome" = "firefox.desktop";
      "x-scheme-handler/feed" = "thunderbird.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/irc" = "hexchat.desktop";
      "x-scheme-handler/mailto" = "thunderbird.desktop";
      "x-scheme-handler/mid" = "thunderbird.desktop";
      "x-scheme-handler/net.thunderbird" = "thunderbird.desktop";
      "x-scheme-handler/news" = "thunderbird.desktop";
      "x-scheme-handler/nntp" = "thunderbird.desktop";
      "x-scheme-handler/snews" = "thunderbird.desktop";
      "x-scheme-handler/webcal" = "thunderbird.desktop";
      "x-scheme-handler/webcals" = "thunderbird.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
    };
    associations.added = {

      "application/download" = [ "gvim.desktop" ];
      "application/gpx+xml" = [ "gpx-viewer.desktop" ];
      "application/gzip" = [ "org.gnome.FileRoller.desktop" ];
      "application/ics" = [ "thunderbird.desktop" ];
      "application/pdf" = [ "org.gnome.Evince.desktop" "firefox.desktop" "gimp.desktop" ];
      "application/postscript" = [ "org.gnome.Evince.desktop" ];
      "application/rss+xml" = [ "thunderbird.desktop" ];
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = [ "writer.desktop" ];
      "application/x-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-executable" = [ "org.gnome.gedit.desktop" "gvim.desktop" ];
      "application/x-extension-htm" = [ "firefox.desktop" ];
      "application/x-extension-html" = [ "firefox.desktop" ];
      "application/x-extension-ics" = [ "thunderbird.desktop" ];
      "application/x-extension-rss" = [ "thunderbird.desktop" ];
      "application/x-extension-shtml" = [ "firefox.desktop" ];
      "application/x-extension-xht" = [ "firefox.desktop" ];
      "application/x-extension-xhtml" = [ "firefox.desktop" ];
      "application/x-ruby" = [ "gvim.desktop" ];
      "application/x-shellscript" = [ "org.gnome.gedit.desktop" "gvim.desktop" ];
      "application/x-xz-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/xhtml+xml" = [ "firefox.desktop" ];
      "application/zip" = [ "org.gnome.FileRoller.desktop" ];
      "image/gif" = [ "wine-extension-mcf.desktop" "eog.desktop" ];
      "image/jpeg" = [ "eog.desktop" "org.gnome.eog.desktop" ];
      "image/png" = [ "eog.desktop" "gimp.desktop" ];
      "image/svg+xml" = [ "org.gnome.eog.desktop" "eog.desktop" ];
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "message/rfc822" = [ "thunderbird.desktop" ];
      "text/calendar" = [ "thunderbird.desktop" "nvim.desktop" ];
      "text/csv" = [ "gnumeric.desktop" ];
      "text/markdown" = [ "org.gnome.gitlab.somas.Apostrophe.desktop" "typora.desktop" ];
      "text/plain" = [ "org.gnome.gedit.desktop" "nvim.desktop" "gvim.desktop" "code-url-handler.desktop" ];
      "text/vcard" = [ "gvim.desktop" ];
      "text/x-csrc" = [ "org.gnome.gedit.desktop" ];
      "text/x-makefile" = [ "org.gnome.gedit.desktop" "gvim.desktop" ];
      "text/x-matlab" = [ "org.gnome.gedit.desktop" "oz.desktop" ];
      "text/x-patch" = [ "org.gnome.gedit.desktop" ];
      "text/xml" = [ "org.gnome.gedit.desktop" "firefox.desktop" ];
      "x-scheme-handler/chrome" = [ "firefox.desktop" ];
      "x-scheme-handler/feed" = [ "thunderbird.desktop" ];
      "x-scheme-handler/mailto" = [ "thunderbird.desktop" ];
      "x-scheme-handler/mid" = [ "thunderbird.desktop" ];
      "x-scheme-handler/net.thunderbird" = [ "thunderbird.desktop" ];
      "x-scheme-handler/news" = [ "thunderbird.desktop" ];
      "x-scheme-handler/nntp" = [ "thunderbird.desktop" ];
      "x-scheme-handler/snews" = [ "thunderbird.desktop" ];
      "x-scheme-handler/webcal" = [ "thunderbird.desktop" ];
      "x-scheme-handler/webcals" = [ "thunderbird.desktop" ];
    };
  };

  # Force-overwrite the config-dir mimeapps.list
  xdg.configFile."mimeapps.list".force = true;

  # Prevent HM from writing the deprecated data-dir copy
  xdg.dataFile."applications/mimeapps.list".enable = lib.mkForce false;

  # Delete any leftover deprecated copy
  home.activation.cleanupDeprecatedMimeapps = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    rm -f "$HOME/.local/share/applications/mimeapps.list"
  '';
}
