{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let

  mediaRoot = "/mnt/media";

  mediaGid = 3000;

  extraNvidiaDevices = [
    "/dev/nvidia0"
    "/dev/nvidia-uvm"
    "/dev/nvidia-uvm-tools"
    "/dev/nvidia-modeset"
  ];
in
{

  services.jellyfin = {
    enable = true;

    openFirewall = true;

    hardwareAcceleration = {
      enable = true;
      type = "nvenc";

      device = "/dev/nvidiactl";
    };

    forceEncodingConfig = true;

    transcoding = {
      enableHardwareEncoding = true;

      hardwareEncodingCodecs = {
        hevc = true;
        av1 = false;
      };

      hardwareDecodingCodecs = {
        h264 = true;
        hevc = true;
        hevc10bit = true;
        vp8 = true;
        vp9 = true;
        av1 = true;
        mpeg2 = true;
        vc1 = true;

      };

      enableToneMapping = true;

      throttleTranscoding = true;

      h264Crf = 21;
      h265Crf = 26;
    };
  };

  systemd.services.jellyfin.serviceConfig.DeviceAllow = map (d: "${d} rw") extraNvidiaDevices;

  fileSystems.${mediaRoot} = {
    device = "/dev/disk/by-uuid/2A0B-58D1";
    fsType = "exfat";
    options = [

      "uid=${toString config.users.users.${username}.uid}"
      "gid=${toString mediaGid}"
      "dmask=0002"
      "fmask=0113"
      "iocharset=utf8"
      "nofail"
      "noatime"
      "x-gvfs-hide"
    ];
  };

  systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ mediaRoot ];

  users.groups.media.gid = mediaGid;

  services.radarr = {
    enable = true;
    group = "media";
    openFirewall = false;
  };

  systemd.services.radarr.unitConfig.RequiresMountsFor = [ mediaRoot ];

  services.sonarr = {
    enable = true;
    group = "media";
    openFirewall = false;
  };

  systemd.services.sonarr.unitConfig.RequiresMountsFor = [ mediaRoot ];

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  environment.systemPackages = with pkgs; [
    jellyfin-ffmpeg
  ];

}
