{ config, pkgs, ... }:

# modules/media-extras.nix — the book/audiobook half of the media stack.
#
# These were previously enabled by hand in configuration.nix and never
# committed, so a config overwrite silently removed them. Declared here so
# they survive.
#
# Lidarr is deliberately NOT here — Tauon (already in systemPackages) covers
# music, and MPD/rmpc handle playback.
#
# Both services read from the media library, so they run in the shared
# `media` group defined in modules/media.nix, and wait on the same mount.

let
  mediaRoot = "/mnt/media";   # must match modules/media.nix
in
{
  # ── Audiobookshelf ───────────────────────────────────────────────────────
  # Audiobook + podcast server, with its own apps and progress sync.
  # Loopback-only like jellyfin/radarr/sonarr — reachable over the tailnet,
  # not the LAN.
  services.audiobookshelf = {
    enable = true;
    host = "127.0.0.1";
    port = 8000;
    group = "media";          # read the library without chmod games (exFAT)
    openFirewall = false;
  };

  systemd.services.audiobookshelf.unitConfig.RequiresMountsFor = [ mediaRoot ];

  # ── Calibre-Web ──────────────────────────────────────────────────────────
  # Web reader / OPDS front-end for an existing Calibre library. It does NOT
  # create one: it needs a metadata.db, so point calibreLibrary at a folder
  # that has been initialised by Calibre itself at least once.
  services.calibre-web = {
    enable = true;
    listen = {
      ip = "127.0.0.1";
      port = 8083;
    };
    group = "media";
    options = {
      calibreLibrary = "${mediaRoot}/books";
      # Uploading writes into the library — off by default since the target
      # is exFAT and permissions there come from mount options, not chmod.
      enableBookUploading = false;
    };
  };

  systemd.services.calibre-web.unitConfig.RequiresMountsFor = [ mediaRoot ];

  # ── whisper.cpp ──────────────────────────────────────────────────────────
  # Local speech-to-text (subtitle generation, transcription). CLI only, no
  # service. This is the CPU build, same as before.
  #
  # For GPU: there's no whisper-cpp-vulkan attribute — vulkanSupport is an
  # override flag, so it's a from-source build with no cache hit:
  #   (pkgs.whisper-cpp.override { vulkanSupport = true; })
  # Worth it only if you transcribe often; the CPU build is fine for
  # occasional subtitle runs on 12 threads.
  environment.systemPackages = [ pkgs.whisper-cpp ];

  # ── Ports, for reference ────────────────────────────────────────────────
  #   8000  audiobookshelf
  #   8083  calibre-web
  #   8096  jellyfin      (media.nix)
  #   7878  radarr        (media.nix)
  #   8989  sonarr        (media.nix)
}
