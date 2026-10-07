{ pkgs, ... }:
{
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # bluetoothd segfaults in a2dp discover_cb (use-after-free of the a2dp
  # setup) when an AVDTP discovery times out after the caller cancelled,
  # e.g. on a flaky headset (re)connect. The SEP cache fix is upstream
  # b7d71e50 (post-5.87); it avoids re-running discovery on every reconnect.
  # Only the daemon is patched: overriding bluez in the global overlay would
  # rebuild everything that links libbluetooth.
  # Drop the cache patch once nixpkgs ships a bluez release containing it.
  hardware.bluetooth.package = assert pkgs.bluez.version == "5.87";
    pkgs.bluez.overrideAttrs (oldAttrs: {
      patches = oldAttrs.patches or [ ] ++ [
        ./bluez/bluez-a2dp-sep-cache.patch
        ./bluez/bluez-a2dp-discover-uaf.patch
      ];
    });
}
