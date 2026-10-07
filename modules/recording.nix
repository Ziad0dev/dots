{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let

  replayDir = "/data/replays";
  inherit (config.dots.recording) monitor;

  gsr = pkgs.gpu-screen-recorder.override { inherit (config.security) wrapperDir; };
in
{
  # the screen-recording shim records the focused output instead
  options.dots.recording.monitor = lib.mkOption {
    type = lib.types.str;
    default = "DP-1";
    description = "Output the replay buffer captures.";
  };

  config = {
    programs.gpu-screen-recorder.enable = true;

    environment.systemPackages = with pkgs; [
      gpu-screen-recorder-gtk
    ];

    systemd.tmpfiles.rules = [
      "d ${replayDir} 0700 ${username} users -"
    ];

    systemd.user.services.gsr-replay = {
      description = "gpu-screen-recorder replay buffer";

      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];

      serviceConfig = {
        Type = "simple";

        ExecStart = lib.concatStringsSep " " [
          (lib.getExe gsr)
          "-w ${monitor}"
          "-f 60"
          "-c mp4"
          "-k hevc"
          "-q very_high"
          "-a default_output|easyeffects_source"
          "-r 300"
          "-o ${replayDir}"
        ];

        ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";
        Restart = "on-failure";
        RestartSec = 5;
        Nice = -5;
      };
    };
  };
}
