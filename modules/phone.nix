{ config, lib, ... }:
let
  cfg = config.dots.phone;
in
{
  # Phones (Android and iPhone) as part of the desktop; the tools and `dots-phone` are in
  # home/phone.nix, docs in docs/desktop.md → Phone.
  options.dots.phone = {
    quickSharePort = lib.mkOption {
      type = lib.types.port;
      default = 53320;
      description = ''
        Fixed TCP port RQuickShare (Android Quick Share) listens on. It picks a random one by
        default, which no firewall rule can allow; `dots-phone quickshare` writes this one into its
        settings before starting it. Opened on the LAN interface only.
      '';
    };
    webcamDevice = lib.mkOption {
      type = lib.types.ints.between 0 255;
      default = 42;
      description = ''
        Number of the v4l2loopback device a phone camera is streamed to (`dots-phone webcam`):
        /dev/video<N>, shown to apps as "Phone camera". Fixed so it never collides with real cameras.
      '';
    };
  };

  config = {
    # phone as a webcam: scrcpy streams the Android camera into this loopback device.
    # exclusive_caps: browsers and call apps only list a v4l2 device as a camera when it
    # advertises capture alone
    boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    boot.kernelModules = [ "v4l2loopback" ];
    boot.extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=${toString cfg.webcamDevice} card_label="Phone camera" exclusive_caps=1
    '';

    networking.firewall.interfaces.${config.dots.lanInterface} = {
      # KDE Connect: discovery (UDP 1716) and connections, the protocol's whole range
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      # RQuickShare transfers; discovery is mDNS (5353, modules/lan.nix) and Bluetooth
      allowedTCPPorts = [ cfg.quickSharePort ];
    };

    environment.sessionVariables = {
      DOTS_QUICKSHARE_PORT = toString cfg.quickSharePort;
      DOTS_PHONE_WEBCAM = "/dev/video${toString cfg.webcamDevice}";
    };
  };
}
