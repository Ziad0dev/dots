{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let

  replayDir = "/data/replays";
  monitor = "DP-1";

  gsr = pkgs.gpu-screen-recorder.override { inherit (config.security) wrapperDir; };
in
{

  programs.gpu-screen-recorder.enable = true;

  environment.systemPackages = with pkgs; [
    gpu-screen-recorder-gtk
  ];

  systemd.tmpfiles.rules = [
    "d ${replayDir} 0755 ${username} users -"
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
        "-a default_output"
        "-r 300"
        "-o ${replayDir}"
      ];

      ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";
      Restart = "on-failure";
      RestartSec = 5;
      Nice = -5;
    };
  };
}
