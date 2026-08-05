{ config, pkgs, ... }:

let
  mediaRoot = "/mnt/media";
in
{

  services.audiobookshelf = {
    enable = true;
    host = "127.0.0.1";
    port = 8000;
    group = "media";
    openFirewall = false;
  };

  systemd.services.audiobookshelf.unitConfig.RequiresMountsFor = [ mediaRoot ];

  services.calibre-web = {
    enable = true;
    listen = {
      ip = "127.0.0.1";
      port = 8083;
    };
    group = "media";
    options = {
      calibreLibrary = "${mediaRoot}/books";

      enableBookUploading = false;
    };
  };

  systemd.services.calibre-web.unitConfig.RequiresMountsFor = [ mediaRoot ];

  environment.systemPackages = [ pkgs.whisper-cpp ];

}
