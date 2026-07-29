{ config, lib, pkgs, username, ... }:

let
  # RTX 3060 (Ampere) NVENC: H.264 and HEVC encode. No AV1 *encode* —
  # that's Ada (40-series) and up. HEVC is the right default here.
  replayDir = "/data/replays";
  monitor = "DP-2"; # primary 1440p240; use "screen" to capture all outputs

  # Same override the NixOS module applies — the binary needs to know where
  # the setcap'd gsr-kms-server lives. On 25.11 the module only creates the
  # wrapper and does NOT add the package to systemPackages, so don't rely on
  # PATH here.
  gsr = pkgs.gpu-screen-recorder.override { inherit (config.security) wrapperDir; };
in
{
  # Installs the package and setcaps gsr-kms-server (cap_sys_admin), which is
  # what lets it capture under Wayland without a portal prompt every time.
  programs.gpu-screen-recorder.enable = true;

  environment.systemPackages = with pkgs; [
    gpu-screen-recorder-gtk # GUI, if you want it
  ];

  systemd.tmpfiles.rules = [
    "d ${replayDir} 0755 ${username} users -"
  ];

  # ShadowPlay-equivalent: always-on 5-minute ring buffer, saved on demand.
  systemd.user.services.gsr-replay = {
    description = "gpu-screen-recorder replay buffer";
    # Only meaningful inside a graphical session.
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];

    serviceConfig = {
      Type = "simple";
      # NOTE: verify flags against `gpu-screen-recorder --help` — the audio
      # (-a) syntax in particular changed across 5.x releases.
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe gsr)
        "-w ${monitor}"
        "-f 60"          # capture fps
        "-c mp4"
        "-k hevc"        # h264 if you need dumb-player compatibility
        "-q very_high"
        "-a default_output"   # desktop audio; add a second -a for the mic
        "-r 300"         # replay buffer length, seconds
        "-ro ${replayDir}"
      ];
      # SIGUSR1 flushes the buffer to disk without stopping the recorder.
      ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";
      Restart = "on-failure";
      RestartSec = 5;
      Nice = -5;
    };
  };
}
