# Nix template for sway config file
# vim: ft=i3

{ lib
, blueman
, brightnessctl
, dbus
, dmenu
, element-desktop
, firefox
, gammastep
, grim
, kanshi
, lockimage
, mako
, networkmanagerapplet
, pasystray
, pulseaudio
, skypeforlinux
, slack
, slurp
, sway
, swayidle
, swaylock
, systemd
, termite
, thunderbird
, udiskie
, waybar
, wl-clipboard
, writeScript
, writeShellScript
, writeShellScriptBin
, writeTextFile
, zim
}:

let
  # Wayland apps have only app_id to match upon
  zimSelector =         ''[app_id="^(?:[Zz]im|\.zim-wrapped)$"]''; # [window_type="normal" title="- Zim$"]

  # XWayland apps have more fields
  slackSelector =       ''[class="^Slack$"                                  instance="^slack$"   ]'';
  riotSelector =        ''[class="^Riot$"      window_role="browser-window" instance="^riot$"    ]'';
  elementSelector =     ''[class="^Element$"   window_role="browser-window" instance="^element$" ]'';
  skypeSelector =       ''[class="(?i)^Skype$" window_type="normal"                              ]'';
  # thunderbirdSelector = ''[class="^Daily$"     window_role="^3pane$"        instance="^Mail$"    ]'';
  # teamsSelector =       ''[class="Microsoft Teams - Preview"     window_role="browser-window" instance="microsoft teams - preview"   ]'';

  swaymsgPath = lib.getExe' sway "swaymsg";

  # These scripts form an extra indirection but save so much on string escape hell.
  # They need to be named like the wrapped executable to make the pkill trick in execAlwaysScript work.
  swaylockScript = writeShellScriptBin "swaylock" ''
    # Make it look like i3lock
    exec ${swaylock}/bin/swaylock --ignore-empty-password --daemonize --image ${lockimage} --scaling=fill --indicator-radius 100
  '';

  swayidleScript = writeShellScriptBin "swayidle" ''
    exec ${swayidle}/bin/swayidle -w before-sleep ${swaylockScript}/bin/swaylock timeout 600 '${swaymsgPath} "output * dpms off"' resume '${swaymsgPath} "output * dpms on"'
  '';

  scratchOnce = writeScript "sway-scratch-once" ''
    #! /usr/bin/env nix-shell
    #! nix-shell -i python -p python3 python3Packages.i3ipc

    import i3ipc
    from time import strftime, gmtime
    from pprint import pprint
    import sys

    i3 = i3ipc.Connection()

    selector = sys.argv[1]

    def on_window(i3, e):
        if e.change != "new": return

        app_id = e.container.app_id
        clazz = e.container.ipc_data.get("window_properties", {}).get("class")
        width = e.container.ipc_data.get("geometry", {}).get("width", 0)

        #if width == 440 and "teams" in selector.lower():
        #    i3.command("""[class="{}"] move scratchpad""".format(selector))
        #    return

        if app_id == selector:
            i3.command("""[app_id="{}"] move scratchpad""".format(selector))
            i3.main_quit()

        if clazz == selector:
            i3.command("""[class="{}"] move scratchpad""".format(selector))
            i3.main_quit()


    i3.on('window', on_window)

    print("Ready to scratch", selector, flush=True)
    i3.main()
  '';


  execScript = writeShellScript "sway-exec-apps" ''

    # XXX: Not really needed here. But prevents race conditions with exec-always-apps
    ${dbus}/bin/dbus-update-activation-environment --systemd --all
    ${systemd}/bin/systemctl --user restart pipewire.service

    function exec () {
      echo "Running $1"
      ${swaymsgPath} -- exec "$@"
    }
    function execAndScratch () {
      local filter=$1; shift

      ${scratchOnce} "$filter" | { read; exec "$@"; } &
    }

    # default is 5700:3500
    exec ${gammastep}/bin/gammastep -l 50.6:4.32 -t 5700:4500
    execAndScratch Slack        ${slack}/bin/slack
    execAndScratch .zim-wrapped ${zim}/bin/zim
    execAndScratch Element      ${element-desktop}/bin/element-desktop
    # execAndScratch "Microsoft Teams - Preview" $-{teams}/bin/teams

    #exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
    #${swaymsgPath} exec ${skypeforlinux}/bin/skypeforlinux
    #exec dropboxd
    #exec transmission-gtk -m

    # Setup workspace 1.
    # TODO exec $ {i3}/bin/i3-msg 'workspace --no-auto-back-and-forth 1; append_layout ~/.i3/workspace1'
    ${swaymsgPath} "workspace --no-auto-back-and-forth 1, exec ${firefox}/bin/firefox"
    ${swaymsgPath} "workspace --no-auto-back-and-forth 1, exec ${thunderbird}/bin/thunderbird"
    ${swaymsgPath} "workspace --no-auto-back-and-forth 1"

    sleep 10
    exit 0
  '';

  execAlwaysScript = writeShellScript "sway-exec-always-apps" ''
    # Work around dbus and systemd not being _aware_ of sway-defined vars.
    #${systemd}/bin/systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK
    #${dbus}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK
    # XXX: We should be able to identify the variables that should be imported.
    #      There is no need to import everything.
    ${dbus}/bin/dbus-update-activation-environment --systemd --all
    #${systemd}/bin/systemctl start graphical.target

    # These apps are restarted on each sway startup
    # It is a bit redundant to call swaymsg here, but it ensures that the app starts in background.
    # Does it ? This script already starts in background itself...
    function exec_always () {
      local bin=$1; shift

      echo "Running $bin"
      pkill "$(basename "$bin")"
      ${swaymsgPath} -- exec_always "$bin" "$@"
    }

    # These services have little state, we can restart them to get the most recent version.
    exec_always ${networkmanagerapplet}/bin/nm-applet --indicator
    exec_always ${udiskie}/bin/udiskie --tray --appindicator -A
    exec_always ${waybar}/bin/waybar
    exec_always ${swayidleScript}/bin/swayidle
    exec_always ${blueman}/bin/blueman-applet
    exec_always ${pasystray}/bin/pasystray

    # kanshi needs restart to override outputs reset changes made by sway reload
    exec_always ${kanshi}/bin/kanshi
  '';

  config = ''
# i3 config file (v4.4)
# vim: ft=i3

# This file was generated by nix. Do not edit.

workspace_auto_back_and_forth yes

set $mod Mod4

# font for window titles. ISO 10646 = Unicode
#font xft:Ubuntu 10
#font xft:Consolas 10
font Cantarell 11
titlebar_border_thickness 1
titlebar_padding 1 1
default_border normal 1
default_floating_border normal 1
#-misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1
#font -misc-ubuntu mono-medium-r-normal-*-0-*-*-*-*-*-iso10646-1
#font -ibm-courier-medium-r-normal-*-*-120-100-100-m-0-iso10646-1

# Use "Pause" as locking action
bindsym Pause           exec "${swaylockScript}/bin/swaylock"
bindsym XF86Sleep       exec "${swaylockScript}/bin/swaylock"
bindsym Shift+Pause     exec "${swaylockScript}/bin/swaylock; exec ${systemd}/bin/systemctl hibernate"
bindsym Shift+XF86Sleep exec "${swaylockScript}/bin/swaylock; exec ${systemd}/bin/systemctl hibernate"
bindsym $mod+w          exec $HOME/bin/nm_toggle
#bindsym $mod+Shift+W exec autorandr -c

#for_window [class="URxvt"]              border pixel 1
for_window [app_id="^termite$"]            border pixel 1
for_window [class="^Termite$" instance="^termite$"] border pixel 1

for_window [title="Oz Browser"]         floating enable
for_window [title="Super Hexagon"]      floating enable
for_window [title="^SpaceChem$"]        floating enable
for_window [class="Gnuplot"]            floating enable
for_window [class="FLTK"]               floating enable
for_window [class="Gtkdialog"]          floating enable
for_window [app_id="zenity"]            floating enable, move absolute position 900 px 700 px
#for_window [title="Notification Microsoft Teams"] floating enable, move position 20 20
#no_focus   [title="Notification Microsoft Teams"]
for_window [window_role="CallWindow"]   floating enable
for_window [title="^EMV-CAP Password$"] floating enable
#for_window [class="Graphviz"]           floating enable
#for_window [title="^Eclipse"]           floating enable
#for_window [title="^client"]            floating enable
#for_window [instance="sun-awt-X11-XFramePeer"] floating enable, move absolute position center
for_window [title="(?i)Netbeans"]       floating disable

for_window [app_id="firefox" title="^Picture-in-picture$"] floating enable, sticky enable, border none
for_window [app_id="firefox" title="— Sharing Indicator$"] floating enable, sticky enable, border none

#for_window ${slackSelector}             move scratchpad
#for_window ${zimSelector}               move scratchpad
#for_window ${riotSelector}              move scratchpad

#assign [class="Zenity"] → 0
assign [class="Firefox"] → 1
assign [class="Thunderbird"] → 1
#assign [class="URxvt" instance="initialTerm"] → 2
assign [class="Pdfpc" window_role="presentation"] → 0
assign [class="Pdfpc" window_role="presentation"] fullscreen enable

exec_always ${execAlwaysScript}
exec ${execScript}

### Key bindings

${let captureProcess = area: builtins.concatStringsSep " | " [
  ''${grim}/bin/grim ${area} -''
  ''tee ~/images/captures/$(date +'%Y-%m-%d-%H%M%S_grim.png')''
  ''${wl-clipboard}/bin/wl-copy''
]; in ''
  bindsym Print exec ${captureProcess ""}
  bindsym Shift+Print exec ${captureProcess ''-g "$(${slurp}/bin/slurp)"''}
''}
# Use sound actions...
# correction : volumeicon handle this. See under.
#exec volumeicon
bindsym XF86AudioRaiseVolume  exec ${pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume  exec ${pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute         exec ${pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym XF86AudioMicMute      exec ${pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ toggle

bindsym XF86MonBrightnessDown exec ${brightnessctl}/bin/brightnessctl s 10%-
bindsym XF86MonBrightnessUp   exec ${brightnessctl}/bin/brightnessctl s +10%
#bindsym XF86WLAN              exec gksu rfkill block all


# Use Mouse+$mod to drag floating windows to their wanted position
floating_modifier $mod

# mouse warping (default: "output")
mouse_warping none

# start a terminal
#bindsym $mod+Return exec i3-sensible-terminal
bindsym $mod+Return exec ${termite}/bin/termite
bindsym $mod+o exec ${termite}/bin/termite -e "bash -c 'vim $(fd . $HOME --hidden | fzf)'"

# kill focused window
bindsym $mod+Shift+C kill

# start dmenu (a program launcher)
#bindsym $mod+p exec "pkill dmenu; exec ${dmenu}/bin/dmenu_run -f -i"
bindsym $mod+p exec termite --name=launcher -e "bash -c 'compgen -c | sort -u | fzf --no-extended --print-query | tail -n1 | xargs -r ${swaymsgPath} -t command exec'"
for_window [app_id="^launcher$"] floating enable, border pixel 5

# restart mako
bindsym $mod+Shift+z exec ${mako}/bin/makoctl restore

# change focus
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right

# alternatively, you can use the cursor keys:
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# move focused window
bindsym $mod+Shift+H move left
bindsym $mod+Shift+J move down
bindsym $mod+Shift+K move up
bindsym $mod+Shift+L move right

# alternatively, you can use the cursor keys:
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# split in horizontal orientation
bindsym $mod+b split h

# split in vertical orientation
bindsym $mod+v split v

bindsym $mod+e layout toggle split

# enter fullscreen mode for the focused container
bindsym $mod+f fullscreen
bindsym $mod+Shift+F fullscreen global

# change container layout (stacked, tabbed, default)
bindsym $mod+s layout stacking
bindsym $mod+t layout tabbed
bindsym $mod+d layout default

# toggle tiling / floating
bindsym $mod+Shift+space floating toggle

# change focus between tiling / floating windows
bindsym $mod+space focus mode_toggle

# focus the parent container
bindsym $mod+a focus parent

# focus the child container
bindsym $mod+q focus child

# switch to workspace
bindsym  $mod+twosuperior workspace 0
bindcode $mod+10 workspace 1
bindcode $mod+11 workspace 2
bindcode $mod+12 workspace 3
bindcode $mod+13 workspace 4
bindcode $mod+14 workspace 5
bindcode $mod+15 workspace 6
bindcode $mod+16 workspace 7
bindcode $mod+17 workspace 8
bindcode $mod+18 workspace 9
bindcode $mod+19 workspace 10

#bindcode $mod+F? workspace "0'"
bindsym $mod+F1 workspace "1'"
bindsym $mod+F2 workspace "2'"
bindsym $mod+F3 workspace "3'"
bindsym $mod+F4 workspace "4'"
bindsym $mod+F5 workspace "5'"
bindsym $mod+F6 workspace "6'"
bindsym $mod+F7 workspace "7'"
bindsym $mod+F8 workspace "8'"
bindsym $mod+F9 workspace "9'"
bindsym $mod+F10 workspace "10'"


# Move to Workspaces
bindsym  $mod+Shift+twosuperior move workspace 0
bindcode $mod+Shift+10 move workspace 1
bindcode $mod+Shift+11 move workspace 2
bindcode $mod+Shift+12 move workspace 3
bindcode $mod+Shift+13 move workspace 4
bindcode $mod+Shift+14 move workspace 5
bindcode $mod+Shift+15 move workspace 6
bindcode $mod+Shift+16 move workspace 7
bindcode $mod+Shift+17 move workspace 8
bindcode $mod+Shift+18 move workspace 9
bindcode $mod+Shift+19 move workspace 10

#bindcode $mod+Shift+F? workspace "0'"
bindsym $mod+Shift+F1 move workspace "1'"
bindsym $mod+Shift+F2 move workspace "2'"
bindsym $mod+Shift+F3 move workspace "3'"
bindsym $mod+Shift+F4 move workspace "4'"
bindsym $mod+Shift+F5 move workspace "5'"
bindsym $mod+Shift+F6 move workspace "6'"
bindsym $mod+Shift+F7 move workspace "7'"
bindsym $mod+Shift+F8 move workspace "8'"
bindsym $mod+Shift+F9 move workspace "9'"
bindsym $mod+Shift+F10 move workspace "10'"


# reload the configuration file
#bindsym $mod+Shift+W reload
# restart i3 inplace (preserves your layout/session, can be used to upgrade i3)
bindsym $mod+Shift+R restart
# exit i3 (logs you out of your X session)
bindsym $mod+Shift+E exit

### Shortcuts for scratchpad easy access ###

# Priviledged zim shortcut
bindsym $mod+z ${zimSelector} scratchpad show

mode "scratch" {
    bindsym z ${zimSelector}        scratchpad show, mode "default"
    bindsym s ${slackSelector}      scratchpad show, mode "default"
    bindsym k ${skypeSelector}      scratchpad show, mode "default"
    bindsym h ${riotSelector}       scratchpad show, mode "default"
    bindsym r ${riotSelector}       scratchpad show, mode "default"
    bindsym e ${elementSelector}    scratchpad show, mode "default"
    bindsym g                       scratchpad show, mode "default"
    bindsym $mod+g                  scratchpad show, mode "default"
    bindsym n                       scratchpad show, mode "scratch-iterate"

    # back to normal: Enter or Escape
    bindsym Return mode "default"
    bindsym Escape mode "default"
}

mode "scratch-iterate" {
    bindsym n                       scratchpad show, scratchpad show
    # fake "scratch"
    bindsym g                       scratchpad show, mode "default"
    bindsym $mod+g                  scratchpad show, mode "default"
    # back to normal: Enter or Escape
    bindsym Return mode "default"
    bindsym Escape mode "default"
}

bindsym $mod+g mode "scratch"
bindsym $mod+Shift+G move scratchpad

# resize window (you can also use the mouse for that)
mode "resize" {
    # These bindings trigger as soon as you enter the resize mode

    # They resize the border in the direction you pressed, e.g.
    # when pressing left, the window is resized so that it has
    # more space on its left

    bindsym j resize shrink left 10 px or 10 ppt
    bindsym Shift+J resize grow   left 10 px or 10 ppt

    bindsym k resize shrink down 10 px or 10 ppt
    bindsym Shift+K resize grow   down 10 px or 10 ppt

    bindsym l resize shrink up 10 px or 10 ppt
    bindsym Shift+L resize grow   up 10 px or 10 ppt

    bindsym semicolon resize shrink right 10 px or 10 ppt
    bindsym Shift+colon resize grow   right 10 px or 10 ppt

    # same bindings, but for the arrow keys
    bindsym Left resize shrink left 10 px or 10 ppt
    bindsym Shift+Left resize grow   left 10 px or 10 ppt

    bindsym Down resize shrink down 10 px or 10 ppt
    bindsym Shift+Down resize grow   down 10 px or 10 ppt

    bindsym Up resize shrink up 10 px or 10 ppt
    bindsym Shift+Up resize grow   up 10 px or 10 ppt

    bindsym Right resize shrink right 10 px or 10 ppt
    bindsym Shift+Right resize grow   right 10 px or 10 ppt

    # back to normal: Enter or Escape
    bindsym Return mode "default"
    bindsym Escape mode "default"
}

bindsym $mod+r mode "resize"

#set $HP "Hewlett Packard LA2405 CZ40022966"
set $dell "Dell Inc. DELL U2415 7MT0196H25AS"
set $eizo "Eizo Nanao Corporation EV2480 43440041"
set $main eDP-1

#bar {
#    output $main
#    mode hide
#    font Inconsolata 11
#}
#
#bar {
#    output $HP
#    mode dock
#    #tray_output primary
#    font Inconsolata 11
#}
#
#bar {
#    #output DP-4
#    mode invisible
#    #status_command true
#    tray_output primary
#}

output * bg #6699cc solid_color
#output $HP mode 1980x1200 transform 270

input * {
    tap enabled
    middle_emulation enabled
    xkb_numlock enabled
    xkb_layout "be"
    xkb_options "eurosign:e,caps:none"
    tap_button_map lmr
}

# Thinkpad keyboard: 1:1:AT_Translated_Set_2_keyboard
# Dell wireless mouse: 1133:16425:Logitech_Dell_WM514
# Sun USB Keyboard: 1072:162:Sun_USB_Keyboard
# Thinkpad trackpoint: 2:10:TPPS/2_Elan_TrackPoint
# Thinkpad touchpad: 1267:12679:ELAN0672:00_04F3:3187_Touchpad
# Thinkpad mouse:    1267:12679:ELAN0672:00_04F3:3187_Mouse
# One by Wacom: 1386:884:Wacom_Intuos_S_Pen


input "1386:884:Wacom_Intuos_S_Pen" {
    map_to_region 31 553 1168 826
}

# HiDPi screen needs bigger cursor :-).
seat * xcursor_theme Adwaita 24

workspace  0 output $main
workspace  1 output $main
workspace  2 output $main
workspace  3 output $main
workspace  4 output $main
workspace  5 output $main
workspace  6 output $main
workspace  7 output $main
workspace  8 output $main
workspace  9 output $main
workspace 10 output $main

workspace  "0'" output $eizo
workspace  "1'" output $eizo
workspace  "2'" output $eizo
workspace  "3'" output $eizo
workspace  "4'" output $eizo
workspace  "5'" output $eizo
workspace  "6'" output $eizo
workspace  "7'" output $eizo
workspace  "8'" output $eizo
workspace  "9'" output $eizo
workspace "10'" output $eizo
'';

in writeTextFile {
    name = "sway-config";
    text = config;
    destination = "/etc/sway/config";
}
