{config, pkgs, lib, ...}:
{
  # needed because bluetooth chipset is not broadcom, and we need at least 5.12
  # latest is 5.13 as of now (aout 2021)
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  # High quality BT calls
  hardware.bluetooth.enable = true;

  # For a PulseAudio bluetooth Stack, maybe already outdated.
  #hardware.pulseaudio.enable = true;
  #hardware.pulseaudio.package = pkgs.pulseaudioFull;
  #hardware.pulseaudio.extraModules = [ pkgs.pulseaudio-modules-bt ];
  #hardware.bluetooth.hsphfpd.enable = true;

  # Pipewire config
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    # No idea if I need this
    #alsa.support32Bit = true;
    pulse.enable = true;

    # High quality BT calls
    wireplumber.enable = true;

    #media-session.config.bluez-monitor.rules = [
    #  {
    #    # Matches all cards
    #    matches = [{ "device.name" = "~bluez_card.*"; }];
    #    actions = {
    #      "update-props" = {
    #         "bluez5.auto-connect" = [ "hfp_hf" "hsp_hs" "a2dp_sink" ];
    #         # mSBC is not expected to work on all headset + adapter combinations.
    #         "bluez5.msbc-support" = true;
    #         # SBC-XQ is not expected to work on all headset + adapter combinations.
    #         "bluez5.sbc-xq-support" = true;
    #         "bluez5.autoswitch-profile" = true;
    #      };
    #    };
    #  }
    #  # Copy over default config, as these rules override everything.
    #  {
    #    matches = [
    #      # Matches all sources
    #      { "node.name" = "~bluez_input.*"; }
    #      # Matches all outputs
    #      { "node.name" = "~bluez_output.*"; }
    #    ];
    #    actions = {
    #      "node.pause-on-idle" = false;
    #    };
    #  }
    #];
  };

}
