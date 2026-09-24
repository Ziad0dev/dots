{ pkgs, ... }:

let
  port = 2283;
  dataRoot = "/data/immich";
  photosRoot = "/mnt/media/photos";

  nvidiaDevices = [
    "/dev/nvidiactl"
    "/dev/nvidia0"
    "/dev/nvidia-uvm"
    "/dev/nvidia-uvm-tools"
    "/dev/nvidia-modeset"
  ];
in
{
  services.immich = {
    enable = true;
    host = "";
    inherit port;
    openFirewall = false;
    mediaLocation = dataRoot;
    accelerationDevices = nvidiaDevices;

    settings = {
      ffmpeg = {
        accel = "nvenc";
        accelDecode = true;
      };
      storageTemplate = {
        enabled = true;
        template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
      };
      machineLearning.urls = [ "http://localhost:3003" ];
    };
  };

  services.postgresql.package = pkgs.postgresql_17;

  systemd.services.immich-server = {
    unitConfig.RequiresMountsFor = [
      "/data"
      photosRoot
    ];
    serviceConfig.ExecStartPre = [
      "+${pkgs.coreutils}/bin/install -d -m 0700 -o immich -g immich ${dataRoot}"
    ];
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];

  services.restic.backups.home = {
    paths = [ dataRoot ];
    exclude = [
      "${dataRoot}/thumbs"
      "${dataRoot}/encoded-video"
    ];
  };
}
