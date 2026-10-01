{
  config,
  lib,
  pkgs,
  ...
}:
let
  script =
    name: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = builtins.readFile (../scripts + "/${name}.sh");
    };

  pyScript =
    name: python: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = ''exec ${python}/bin/python3 ${../scripts + "/${name}.py"} "$@"'';
    };

  look = script "dots-look" (
    with pkgs;
    [
      coreutils
      findutils
      gnugrep
      gnused
      fuzzel
      libnotify
    ]
  );

  songrec = script "dots-songrec" (
    with pkgs;
    [
      coreutils
      gawk
      gnused
      jq
      libnotify
      pipewire
      pkgs.songrec
      wireplumber
      wl-clipboard
    ]
  );

  lens = script "dots-lens" (
    with pkgs;
    [
      grim
      libnotify
      slurp
      util-linux
      wl-clipboard
      xdg-utils
    ]
  );

  usbSound = pkgs.writeShellApplication {
    name = "dots-usb-sound";
    runtimeInputs = with pkgs; [
      coreutils
      pipewire
      systemd
    ];
    runtimeEnv.DOTS_SOUNDS = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo";
    text = builtins.readFile ../scripts/dots-usb-sound.sh;
  };

  mono = script "dots-mono" (
    with pkgs;
    [
      coreutils
      gnused
      jq
      libnotify
      pipewire
      systemd
      wireplumber
    ]
  );

  timemachine = script "dots-timemachine" (
    with pkgs;
    [
      coreutils
      fzf
      gawk
      git
      gnused
    ]
  );

  diskio = pyScript "dots-diskio" pkgs.python3 [ ];

  screentime = pyScript "dots-screentime" pkgs.python3 [ pkgs.procps ];

  say = pyScript "dots-say" (pkgs.python3.withPackages (ps: [
    ps.kokoro
    ps.en_core_web_sm
  ])) (
    with pkgs;
    [
      libnotify
      pipewire
      wl-clipboard
    ]
  );
in
{
  options.dots.tts.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install dots-say (Kokoro text to speech). Pulls in torch and spaCy.";
  };

  config = {
    home.packages = [
      look
      songrec
      lens
      usbSound
      mono
      timemachine
      diskio
      screentime
      pkgs.songrec
    ]
    ++ lib.optional config.dots.tts.enable say;

    systemd.user.services.dots-usb-sound = {
      Unit = {
        Description = "Play a sound when USB devices are plugged or unplugged";
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
      };
      Service = {
        ExecStart = "${usbSound}/bin/dots-usb-sound watch";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };

    systemd.user.services.dots-screentime = {
      Unit = {
        Description = "Record focused-app time from Hyprland";
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
      };
      Service = {
        ExecStart = "${screentime}/bin/dots-screentime daemon";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };
  };
}
