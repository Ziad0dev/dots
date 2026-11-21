{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let

  hardening = import ../lib/hardening.nix // {
    ProtectSystem = "full";
    ReadWritePaths = [ mediaRoot ];
  };

  mediaRoot = "/mnt/media";

  mediaGid = 3000;

  # a oneshot running `tailscale <verb>` for the bar's Tailscale panel
  tailscaleUnit = verb: {
    description = "Tailscale ${verb} (bar panel)";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    serviceConfig = import ../lib/hardening.nix // {
      Type = "oneshot";
      ExecStart = "${config.services.tailscale.package}/bin/tailscale ${verb}";
      # a logged-out node would wait for a login URL
      TimeoutStartSec = "30s";
      ProtectSystem = "strict";
      # only tailscaled's unix socket
      RestrictAddressFamilies = [ "AF_UNIX" ];
      IPAddressDeny = "any";
    };
  };

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

    openFirewall = false;

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
  services.plex = {
    enable = true;

    # LAN interface only, same as Jellyfin (see modules/lan.nix)
    openFirewall = false;

    # runs as the default `plex` user, but in the media group so it can
    # read/write under dmask=0002; dataDir stays on the system disk
    group = "media";

    # NVENC transcode devices, mirroring Jellyfin's DeviceAllow above
    accelerationDevices = [
      "/dev/nvidiactl"
      "/dev/nvidia0"
      "/dev/nvidia-uvm"
      "/dev/nvidia-uvm-tools"
      "/dev/nvidia-modeset"
    ];
  };

  systemd.services.plex.unitConfig.RequiresMountsFor = [ mediaRoot ];

  systemd.services.jellyfin.serviceConfig.DeviceAllow = map (d: "${d} rw") extraNvidiaDevices;

  fileSystems.${mediaRoot} = {
    device = "/dev/disk/by-uuid/2A0B-58D1";
    fsType = "exfat";
    noCheck = true;
    options = [

      "uid=${toString config.users.users.${username}.uid}"
      "gid=${toString mediaGid}"
      "dmask=0002"
      "fmask=0113"
      "iocharset=utf8"
      "nofail"
      "noatime"
      "x-gvfs-show"
      "x-systemd.automount"
    ];
  };

  systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ mediaRoot ];

  users.groups.media.gid = mediaGid;

  services.radarr = {
    enable = true;
    group = "media";
    openFirewall = false;
    # Prowlarr runs in the wg namespace and reaches the host over its bridge.
    # The host firewall below limits access to that namespace only.
    settings.server.bindaddress = "0.0.0.0";
  };

  systemd.services.radarr.unitConfig.RequiresMountsFor = [ mediaRoot ];
  systemd.services.radarr.serviceConfig = hardening;

  services.sonarr = {
    enable = true;
    group = "media";
    openFirewall = false;
    # Prowlarr runs in the wg namespace and reaches the host over its bridge.
    # The host firewall below limits access to that namespace only.
    settings.server.bindaddress = "0.0.0.0";
  };

  systemd.services.sonarr.unitConfig.RequiresMountsFor = [ mediaRoot ];
  systemd.services.sonarr.serviceConfig = hardening;

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  # The bar's Tailscale panel connects and disconnects by starting these two
  # units. Making the user the Tailscale operator instead would also let any
  # user process run `tailscale serve`/`funnel` and publish local services.
  systemd.services.tailscale-connect = tailscaleUnit "up";
  systemd.services.tailscale-disconnect = tailscaleUnit "down";

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var units = ["tailscale-connect.service", "tailscale-disconnect.service"];
      if (action.id == "org.freedesktop.systemd1.manage-units"
          && subject.user == "${username}"
          && action.lookup("verb") == "start"
          && units.indexOf(action.lookup("unit")) >= 0) {
        return polkit.Result.YES;
      }
    });
  '';

  # 8443: Jellyfin over HTTPS via `tailscale serve --https 8443` (set by hand)
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    8096
    8443
    8920
  ];

  environment.systemPackages = with pkgs; [
    jellyfin-ffmpeg
  ];

}
