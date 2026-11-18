{ pkgs, ... }:

{
  security.rtkit.enable = true;

  boot.kernelParams = [ "threadirqs" ];

  security.pam.loginLimits = [
    {
      domain = "@audio";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
    {
      domain = "@audio";
      item = "rtprio";
      type = "-";
      value = "99";
    }
    {
      domain = "@audio";
      item = "nice";
      type = "-";
      value = "-19";
    }
  ];

  services.udev.extraRules = ''
    KERNEL=="cpu_dma_latency", GROUP="audio", MODE="0660"
  '';

  # JACK programs reach PipeWire through `pw-jack <program>`; the old
  # services.pipewire.jack.enable put its libjack on every program's
  # LD_LIBRARY_PATH and is deprecated.
  environment.systemPackages = [ pkgs.pipewire.jack ];

  services.pipewire = {

    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
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

    # Rules for this machine's own devices (a USB DAC's pinned profile) name
    # them by model and serial number, so they stay out of this public repo,
    # in ~/.config/wireplumber/wireplumber.conf.d/ (read by the user's
    # WirePlumber as well as these).
  };
}
