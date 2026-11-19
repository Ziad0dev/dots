{ config, pkgs, ... }:

let
  mediaRoot = "/mnt/media";
  hardening = import ../lib/hardening.nix;
in
{

  services.audiobookshelf = {
    enable = true;
    host = "127.0.0.1";
    port = 8000;
    group = "media";
    openFirewall = false;
  };

  systemd.services.audiobookshelf = {
    unitConfig.RequiresMountsFor = [ mediaRoot ];
    serviceConfig = hardening;
  };

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

  # whisper.cpp takes its compute backends from llama.cpp's ggml, and the
  # default build is CPU-only. With CUDA it reuses the same CUDA llama.cpp as
  # modules/llm.nix (prebuilt in the CUDA cache); voxtype's dictation runs on
  # the GPU (about 6x faster here).
  environment.systemPackages = [ (pkgs.whisper-cpp.override { cudaSupport = true; }) ];

}
