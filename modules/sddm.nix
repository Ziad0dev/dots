{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.dots.sddm;

  src = ../config/sddm/dots;
  themeDir = ../config/themes + "/${cfg.theme}";
  logoSrc = ../config/quickshell/rise/assets/nixos-logo.png;

  keys = [
    "background"
    "foreground"
    "accent"
    "red"
    "yellow"
  ];
  varlist = lib.concatMapStrings (k: "\${${k}}") keys;

  greeter = pkgs.runCommand "sddm-theme-dots" {
    nativeBuildInputs = [
      pkgs.gettext
      pkgs.imagemagick
    ];
  } ''
    dir="$out/share/sddm/themes/dots"
    mkdir -p "$dir"
    cp ${src}/Main.qml ${src}/metadata.desktop "$dir/"

    set -a
    . ${themeDir}/colors.sh
    set +a

    envsubst '${varlist}' <${src}/theme.conf.in >"$dir/theme.conf"

    if magick ${logoSrc} -alpha extract -background "$accent" -alpha shape "$dir/logo.png"; then
      echo "logo=logo.png" >>"$dir/theme.conf"
    fi

    ${lib.optionalString cfg.wallpaper ''
      for f in ${themeDir}/wallpaper.*; do
        [ -f "$f" ] || continue
        magick "$f" -resize 2560x -blur 0x18 -modulate 45 "$dir/wallpaper.jpg"
        echo "wallpaper=wallpaper.jpg" >>"$dir/theme.conf"
        break
      done
    ''}
  '';
in
{
  options.dots.sddm = {
    theme = lib.mkOption {
      type = lib.types.str;
      default = "kanagawa";
      description = "Theme under config/themes whose colors.sh is baked into the greeter.";
    };

    wallpaper = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Bake a pre-blurred copy of the theme wallpaper behind the greeter.";
    };

    live = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Let themectl override greeter colours via /var/lib/dots-theme/sddm.json.";
    };
  };

  config = {
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      theme = lib.mkForce "dots";
      settings.General.GreeterEnvironment = lib.mkIf cfg.live "QML_XHR_ALLOW_FILE_READ=1";
    };

    environment.systemPackages = [ greeter ];

    systemd.tmpfiles.rules = lib.mkIf cfg.live [
      "d /var/lib/dots-theme 0755 ${username} users -"
    ];
  };
}
