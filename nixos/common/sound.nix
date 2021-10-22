{config, pkgs, lib, ...}:
{
  # needed because bluetooth chipset is not broadcom, and we need at least 5.12 
  # latest is 5.13 as of now (aout 2021)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # High quality BT calls
  hardware.bluetooth.enable = true;
  hardware.bluetooth.hsphfpd.enable = true;

  # See sound.nix
  #hardware.pulseaudio.enable = true;
  #hardware.pulseaudio.package = pkgs.pulseaudioFull;
  #hardware.pulseaudio.extraModules = [ pkgs.pulseaudio-modules-bt ];

  # Pipewire config
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    # No idea if I need this
    alsa.support32Bit = true;
    pulse.enable = true;

    # High quality BT calls
    media-session.config.bluez-monitor.rules = [
      {
        # Matches all cards
        matches = [{ "device.name" = "~bluez_card.*"; }];
        actions = {
          "update-props" = {
            "bluez5.auto-connect" = [ "hfp_hf" "hsp_hs" "a2dp_sink" ];
             # mSBC is not expected to work on all headset + adapter combinations.
             "bluez5.msbc-support" = true;
             # SBC-XQ is not expected to work on all headset + adapter combinations.
             "bluez5.sbc-xq-support" = true;
          };
        };
      }
      {
        matches = [
          # Matches all sources
          { "node.name" = "~bluez_input.*"; }
          # Matches all outputs
          { "node.name" = "~bluez_output.*"; }
        ];
        actions = {
          "node.pause-on-idle" = false;
        };
      }
    ];
  };

}
