{ config, lib, pkgs, username, ... }:

let
  # Library root. The 10 TB external (exFAT, label "10TBackup") declared as a
  # real mount below rather than left to udisks. udiskie puts it at
  # /run/media/${username}/10TBackup, but that directory is 0700 and only
  # exists after you log in — the jellyfin user can't traverse it, and the
  # service starts long before it appears.
  mediaRoot = "/mnt/media";

  # Shared group for anything that needs to write into the library. exFAT has no
  # ownership of its own, so gid= below is what actually grants this — pinned to
  # a literal because mount options take a number, not a name.
  mediaGid = 3000;

  # RTX 3060 (Ampere, GA106), same silicon recording.nix drives:
  #   encode: H.264, HEVC 8/10-bit. No AV1 encode — Ada (40-series) and up.
  #   decode: H.264, HEVC 8/10-bit, VP8, VP9, MPEG-2, VC-1, AV1.
  # NVENC has no concurrent-session cap on Linux with the current driver, so
  # the replay buffer and a couple of transcodes coexist without fighting.
  #
  # The 12400F has no iGPU, so there is no QuickSync fallback. If NVENC is
  # unavailable the encode silently drops to libx264 on six P-cores — watch for
  # that rather than assuming hardware is being used.

  # Every device node jellyfin-ffmpeg's CUDA path opens. The module only wires
  # up hardwareAcceleration.device, which suffices for a single /dev/dri render
  # node but not for NVIDIA's spread. /dev/nvidiactl comes from the module, so
  # it's excluded here.
  extraNvidiaDevices = [
    "/dev/nvidia0"
    "/dev/nvidia-uvm"
    "/dev/nvidia-uvm-tools"
    "/dev/nvidia-modeset"
  ];
in
{
  # ── Server ────────────────────────────────────────────────────────────────
  services.jellyfin = {
    enable = true;

    # Deliberately closed. Reachable over the tailnet only (see below); flip to
    # true only if you decide to port-forward and expose it publicly.
    openFirewall = true;

    hardwareAcceleration = {
      enable = true;
      type   = "nvenc";
      # NVENC doesn't take a device path the way VAAPI does. This exists to
      # satisfy the module's assertion and to seed DeviceAllow; the remaining
      # nodes are appended further down.
      device = "/dev/nvidiactl";
    };

    # Makes encoding.xml a build product rather than something the web
    # dashboard owns. Consistent with the rest of this config, but it does mean
    # transcoding changes made in the UI are reverted on the next restart — set
    # to false if you'd rather tune it live. Existing encoding.xml is backed up
    # to encoding.xml.backup-<timestamp> on first apply.
    forceEncodingConfig = true;

    transcoding = {
      enableHardwareEncoding = true;

      # h264 is always on. hevc gives much better quality per bit for remote
      # streaming, but some older TV clients won't accept it and will force a
      # second transcode — turn it off if you see that.
      hardwareEncodingCodecs = {
        hevc = true;
        av1  = false;   # Ampere cannot encode AV1
      };

      hardwareDecodingCodecs = {
        h264      = true;
        hevc      = true;
        hevc10bit = true;
        vp8       = true;
        vp9       = true;
        av1       = true;   # decode only, and Ampere does have it
        mpeg2     = true;
        vc1       = true;
        # hevcRExt* left off: 4:4:4 RExt decode is Ada and up.
      };

      # HDR -> SDR via the CUDA tonemap filter. Without this, HDR sources sent
      # to an SDR client come out grey and washed out.
      enableToneMapping = true;

      # Pauses the encoder once it runs far enough ahead of playback. Good for
      # sit-and-watch viewing; the first thing to disable if remote playback
      # stalls on seek.
      throttleTranscoding = true;

      # Slightly tighter than the 23/28 defaults. NVENC is fast enough here
      # that the extra bitrate costs nothing in headroom.
      h264Crf = 21;
      h265Crf = 26;
    };
  };

  # The module's DeviceAllow is a whitelist — once it's set, anything not
  # listed is denied. serviceConfig list options concatenate across
  # definitions, so this appends rather than replaces.
  systemd.services.jellyfin.serviceConfig.DeviceAllow =
    map (d: "${d} rw") extraNvidiaDevices;

  # ── Library storage ───────────────────────────────────────────────────────
  # exFAT carries no ownership or permission bits, so the driver synthesises
  # them at mount time from these options. You own everything; the shared media
  # group gets write so radarr can rename and reorganise; everyone else — which
  # in practice means the jellyfin user — reads through the "other" bits.
  #
  # Declaring this here takes the drive away from udisks, exactly like the note
  # about the music drive in configuration.nix: it will stop appearing at
  # /run/media/${username}/10TBackup and stop being ejectable from the file
  # manager. Anything referencing the old path needs updating.
  #
  # UUID rather than label: labels are mutable and you have three exFAT
  # externals, so a relabel or a swap shouldn't be able to silently point this
  # at the wrong volume. 2A0B-58D1 is sda1, the 10 TB one.
  fileSystems.${mediaRoot} = {
    device  = "/dev/disk/by-uuid/2A0B-58D1";
    fsType  = "exfat";
    options = [
      # Derived rather than hardcoded — the uid is pinned in configuration.nix
      # precisely so this can't drift out of sync. It is 1001 here, not the
      # usual 1000.
      "uid=${toString config.users.users.${username}.uid}"
      "gid=${toString mediaGid}"   # shared media group — lets radarr rename
      "dmask=0002"    # dirs  rwxrwxr-x
      "fmask=0113"    # files rw-rw-r--
      "iocharset=utf8"
      "nofail"        # don't wedge boot if the drive is unplugged
      "noatime"       # nothing should be writing to this volume at all
      "x-gvfs-hide"   # keep it out of the file manager's removable list
    ];
  };

  # Wait for the drive instead of racing it. nofail means boot proceeds without
  # it; this means jellyfin won't come up scanning an empty directory.
  systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ mediaRoot ];

  # ── Library management (Radarr) ───────────────────────────────────────────
  # Used here for organising, not acquiring: it matches your existing files
  # against TMDB, renames them into a consistent scheme, and tracks what you
  # own. No indexers or download clients are configured by this module.
  users.groups.media.gid = mediaGid;

  services.radarr = {
    enable = true;
    group  = "media";        # write access to the library via the gid above
    openFirewall = false;    # reachable over the tailnet, same as jellyfin
  };

  systemd.services.radarr.unitConfig.RequiresMountsFor = [ mediaRoot ];

  # ── TV library management (Sonarr) ────────────────────────────────────────
  # Radarr is films only; Sonarr is the same application for series. Same
  # posture: organising and cataloguing, no indexers or download clients.
  services.sonarr = {
    enable = true;
    group  = "media";        # same shared gid, so it can rename in the library
    openFirewall = false;    # tailnet/loopback only
  };

  systemd.services.sonarr.unitConfig.RequiresMountsFor = [ mediaRoot ];

  #   Web UI: http://100.111.248.58:8989 over the tailnet (7878 is radarr).
  #
  # The same two exFAT constraints apply — Settings -> Media Management,
  # with Show Advanced on:
  #   "Set Permissions"                  = OFF   (exFAT has no chmod)
  #   "Use Hardlinks instead of Copy"    = OFF   (no hardlinks either)
  #
  # Root folder to add: ${mediaRoot}/Shows
  #
  # Sonarr matches series folders against TVDB, so folder names have to be
  # actual series titles — the sg-1 / sg-atlantis / sg-universe folders won't
  # resolve until they're renamed to "Stargate SG-1" and so on. Episodes want
  # a Season NN subfolder and SxxEyy in the filename to group properly.

  # Radarr's DB and config live here, on the LUKS SSD rather than the exFAT
  # volume — exFAT has no journal and SQLite on it is a corruption waiting to
  # happen.
  #   Web UI: http://100.111.248.58:7878 over the tailnet.
  #
  # Two settings that MUST be changed from their defaults, because exFAT can't
  # support them and Radarr will throw on every import otherwise:
  #
  #   Settings -> Media Management -> Permissions -> "Set Permissions" = OFF
  #     exFAT has no chmod. Leaving this on produces a failed operation for
  #     every file it touches.
  #
  #   Settings -> Media Management -> "Use Hardlinks instead of Copy" = OFF
  #     FAT-family filesystems have no hardlinks. Radarr falls back to copying
  #     anyway, but turning it off avoids a misleading error first.
  #
  # Root folder to add in the UI: ${mediaRoot}/Movies
  # Renaming is opt-in — Media Management -> "Rename Movies" — and worth
  # running against the existing library, which is where the scene-release
  # filenames come from.

  # ── Remote access ─────────────────────────────────────────────────────────
  # Tailscale over port-forwarding: no inbound ports, no dynamic-DNS, and it
  # survives CGNAT if your ISP ever puts you behind one.
  services.tailscale = {
    enable = true;
    openFirewall = true;   # UDP 41641, for direct paths instead of DERP relay
  };

  # Trusting tailscale0 is what makes 8096 reachable to your devices while the
  # public firewall stays shut.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # After the first `sudo tailscale up`, run once:
  #   sudo tailscale serve --bg 8096
  # That publishes Jellyfin at https://nixos.<your-tailnet>.ts.net with a real
  # Let's Encrypt cert, so the mobile clients get TLS without you owning a
  # domain. `tailscale serve status` to inspect, `tailscale serve --https=443
  # off` to undo.
  #
  # Alternative, if you want people outside the tailnet to watch: port-forward
  # 80/443 and terminate with Caddy instead. Then set openFirewall = false
  # above (already is) and drop the trustedInterfaces line.
  #
  # services.caddy = {
  #   enable = true;
  #   virtualHosts."media.example.tld".extraConfig = ''
  #     reverse_proxy 127.0.0.1:8096
  #   '';
  # };
  # networking.firewall.allowedTCPPorts = [ 80 443 ];

  environment.systemPackages = with pkgs; [
    jellyfin-ffmpeg   # for the verification step below
  ];

  # ── Verifying hardware transcode actually engaged ─────────────────────────
  # The failure mode here is silent: Jellyfin falls back to software and just
  # looks slow. In order:
  #
  #   1. jellyfin-ffmpeg -hide_banner -encoders | grep nvenc
  #      Should list h264_nvenc and hevc_nvenc. nixpkgs builds jellyfin-ffmpeg
  #      from ffmpeg_7-full, which has --enable-nvenc/nvdec/cuda on by default,
  #      so this should pass out of the box.
  #   2. Start a transcode, then `nvtop` (already in llm.nix's package set) —
  #      the ENC block should show activity, not just DEC.
  #   3. Dashboard -> Playback should report the transcode reason and the codec
  #      chain; look for "nvenc" in it.
  #
  # If ffmpeg reports a CUDA init failure in `journalctl -u jellyfin`, the
  # usual cause is the sandbox rather than the driver. PrivateUsers = true is
  # set upstream and CUDA generally tolerates it, but it's the first thing to
  # relax:
  #
  #   systemd.services.jellyfin.serviceConfig.PrivateUsers = lib.mkForce false;
  #
  # Note that libnpp is NOT in this build (nixpkgs gates it behind
  # config.cudaSupport, which would mean a from-source CUDA rebuild with no
  # binary cache). Jellyfin only wants NPP for scale_npp; scale_cuda and
  # tonemap_cuda both work without it, so this costs you nothing real.
  #
  # Transcode scratch lands in /var/cache/jellyfin, i.e. on the root LUKS
  # volume. If you'd rather it not churn there, set the transcode path to
  # somewhere under /data in Dashboard -> Playback (it isn't a Nix option).
}
