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

  voice =
    let
      base = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium";
    in
    {
      model = pkgs.fetchurl {
        url = "${base}.onnx";
        hash = "sha256-s6bke1e4x/vmoM4lGBYaUPWanN2KUINcAssCvdYgbBg=";
      };
      config = pkgs.fetchurl {
        url = "${base}.onnx.json";
        hash = "sha256-laI+tNQpCdON9zu5rH9F9Zfb/N4tG/lSb96vVGaXfXc=";
      };
    };

  usbVoice = pkgs.runCommand "dots-usb-voice" { nativeBuildInputs = [ pkgs.piper-tts ]; } ''
    mkdir -p $out voice
    ln -s ${voice.model} voice/en_US-amy-medium.onnx
    ln -s ${voice.config} voice/en_US-amy-medium.onnx.json
    echo "USB device plugged in." | piper -m voice/en_US-amy-medium.onnx -f $out/device-added.wav
    echo "USB device unplugged." | piper -m voice/en_US-amy-medium.onnx -f $out/device-removed.wav
  '';

  usbSound = pkgs.writeShellApplication {
    name = "dots-usb-sound";
    runtimeInputs = with pkgs; [
      coreutils
      pipewire
      systemd
    ];
    runtimeEnv.DOTS_SOUNDS = "${usbVoice}";
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

  gif = script "dots-gif" (
    with pkgs;
    [
      coreutils
      ffmpeg
    ]
  );

  wallpapers = script "dots-wallpapers" (
    with pkgs;
    [
      coreutils
      findutils
      git
    ]
  );

  diskio = pyScript "dots-diskio" pkgs.python3 [ ];

  screentime = pyScript "dots-screentime" pkgs.python3 [ pkgs.procps ];

  say = pyScript "dots-say" (pkgs.python3.withPackages (ps: [
    ps.kokoro
    ps.spacy-models.en_core_web_sm
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
    default = false;
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
      gif
      wallpapers
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
        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_NETLINK"
        ];
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
        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [ "AF_UNIX" ];
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };
  };
}
