{ ... }:

{
  security.rtkit.enable = true;

  services.pipewire = {

    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;

    extraConfig.pipewire."92-hifi-rates" = {
      "context.properties" = {
        "default.clock.allowed-rates" = [
          44100
          48000
          88200
          96000
          176400
          192000
        ];

      };
    };

    extraConfig.pipewire-pulse."92-hifi-resample" = {
      "stream.properties" = {
        "resample.quality" = 10;
      };
    };
    extraConfig.client."92-hifi-resample" = {
      "stream.properties" = {
        "resample.quality" = 10;
      };
    };

    wireplumber.extraConfig."51-pin-profile" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "device.name" = "alsa_card.usb-EPZ_Technology_G30_3302128F250725-00"; }
          ];
          actions.update-props."device.profile" = "output:analog-stereo+input:mono-fallback";
        }
      ];
    };

  };
}
