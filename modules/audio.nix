{ config, lib, pkgs, ... }:

# Hi-res / hifi audio path. Wire into flake.nix like gaming.nix.
#
# What it does: stops PipeWire resampling everything to 48 kHz. With
# allowed-rates set and NO default.clock.rate pinned, the graph follows the
# stream's native rate — your DAC's display should flip between 44.1/96/192
# as tracks change instead of sitting on "48".

let
  # Flip to true ONLY if rate switching still doesn't happen after testing
  # the rates config alone. Disables the ALSA-Card-Profile layer for USB
  # cards only (deliberately NOT for the GPU's HDMI audio — killing ACP
  # globally breaks profile switching on your monitors). Node names change
  # when ACP goes away, so expect to re-pick outputs once.
  disableAcpOnUsb = false;
in
{
  security.rtkit.enable = true;

  services.pipewire = {
    # Sole owner of the pipewire tree now — the block that lived in
    # configuration.nix moved here (jack + wireplumber carried over).
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;

    extraConfig.pipewire."92-hifi-rates" = {
      "context.properties" = {
        "default.clock.allowed-rates" = [ 44100 48000 88200 96000 176400 192000 ];
        # NOTE: deliberately no default.clock.rate — pinning it defeats
        # dynamic rate switching.
      };
    };

    # When mixing DOES force a resample (two streams at different rates),
    # do it at max quality instead of the cheaper default.
    extraConfig.pipewire-pulse."92-hifi-resample" = {
      "stream.properties" = { "resample.quality" = 10; };
    };
    extraConfig.client."92-hifi-resample" = {
      "stream.properties" = { "resample.quality" = 10; };
    };

    wireplumber.extraConfig = lib.mkIf disableAcpOnUsb {
      "51-usb-no-acp" = {
        "monitor.alsa.rules" = [
          {
            matches = [ { "device.name" = "~alsa_card.usb-.*"; } ];
            actions.update-props = { "api.alsa.use-acp" = false; };
          }
        ];
      };
    };
  };
}
