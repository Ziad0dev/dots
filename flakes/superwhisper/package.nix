# Superwhisper's prebuilt Linux release, made to run on NixOS. The upstream
# install.sh installs distro packages and copies the app into ~/.local, so
# none of it is used: the archive goes into the store, the binaries are
# patched to find their libraries, and run.sh gets the programs and GObject
# typelibs that dependencies.sh would have installed.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  zstd,
  python3,
  glib,
  gtk4,
  gtk4-layer-shell,
  gdk-pixbuf,
  librsvg,
  cairo,
  pango,
  harfbuzz,
  graphene,
  at-spi2-core,
  gobject-introspection,
  libxcb,
  libxkbcommon,
  wayland,
  fontconfig,
  vulkan-loader,
  libnotify,
  wl-clipboard,
  wtype,
  ffmpeg-headless,
  pulseaudio,
  pipewire,
  coreutils,
}:

let
  version = "1.3.1";
  # From the release's .sha256 files; the archive is also minisign-signed
  # (key in the archive's app/assets/linux-release.pub).
  sources = {
    x86_64-linux = {
      arch = "x86_64";
      hash = "sha256-RkpzLKbJKNPyuLuUaHF2p1yisJwYYzPTTZTQUcy18OQ=";
    };
    aarch64-linux = {
      arch = "aarch64";
      hash = "sha256-pEDIXqMb2ww8Oz3pcaBCQCzGmO+ifFTcVzyVU/0o8G8=";
    };
  };
  src =
    sources.${stdenv.hostPlatform.system}
      or (throw "superwhisper: unsupported system ${stdenv.hostPlatform.system}");

  python = python3.withPackages (ps: [
    ps.pygobject3
    ps.pycairo
  ]);

  # dlopen'd at runtime rather than linked: the settings window loads the
  # Wayland client and xkbcommon, the workers Vulkan, doctor.py and the
  # recording pill gtk4-layer-shell.
  runtimeLibs = [
    wayland
    libxkbcommon
    vulkan-loader
    gtk4-layer-shell
  ];

  typelibs = [
    glib
    gtk4
    gtk4-layer-shell
    gdk-pixbuf
    pango
    harfbuzz
    graphene
    at-spi2-core
    gobject-introspection
    libnotify
  ];

  # doctor.py's command list, minus hyprctl and systemctl, which come from
  # the session (they must match the running compositor and user manager).
  runtimePrograms = [
    python
    libnotify # notify-send
    wl-clipboard # wl-copy, wl-paste
    wtype # paste on wlroots compositors other than Hyprland
    ffmpeg-headless
    pulseaudio # pactl, parec, paplay (talking to pipewire-pulse)
    pipewire # pw-record
    fontconfig # fc-cache
    coreutils
  ];
in
stdenv.mkDerivation {
  pname = "superwhisper";
  inherit version;

  src = fetchurl {
    url = "https://github.com/superultrainc/superwhisper-linux-releases/releases/download/v${version}/superwhisper-omarchy-${src.arch}-${version}.tar.zst";
    inherit (src) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    zstd
  ];

  buildInputs = [
    stdenv.cc.cc.lib # libstdc++, libgcc_s, libgomp
    vulkan-loader
    gtk4
    gdk-pixbuf
    cairo
    graphene
    glib
    libxcb
    fontconfig
    libxkbcommon
  ];

  # The fcitx5 addon is loaded by fcitx5 itself, which brings its own
  # libraries; it isn't used without fcitx5.
  autoPatchelfIgnoreMissingDeps = [
    "libFcitx5Core.so.7"
    "libFcitx5Utils.so.2"
  ];

  dontConfigure = true;
  dontBuild = true;
  # Stripping the prebuilt workers gains nothing and risks breaking them.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Same check upstream install.sh runs: every file the release lists.
    sha256sum --quiet -c MANIFEST.sha256

    app=$out/share/superwhisper/app
    mkdir -p "$app" $out/bin
    cp -a app/. "$app/"

    # The in-app updater writes new releases into ~/.local/share/superwhisper;
    # on Nix the store copy is the release, so `update` is refused in run.sh
    # itself (the app calls run.sh directly, not only through bin/) and new
    # versions come from bumping this file (scripts/superwhisper-bump.py).
    substituteInPlace "$app/run.sh" --replace-fail \
      'exec python3 "$loop_dir/scripts/update.py" "$@"' \
      'echo "superwhisper: updates come from the Nix package, not the in-app updater" >&2; exit 1'
    patchShebangs "$app/run.sh" "$app/scripts"

    makeWrapper "$app/run.sh" $out/bin/superwhisper \
      --prefix PATH : ${lib.makeBinPath runtimePrograms} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --prefix GI_TYPELIB_PATH : ${lib.makeSearchPath "lib/girepository-1.0" typelibs} \
      --set-default GDK_PIXBUF_MODULE_FILE ${librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache

    for png in "$app"/assets/app-icon/*.png; do
      size=$(basename "$png" .png)
      [[ "$size" =~ ^[0-9]+$ ]] || continue
      install -Dm0644 "$png" "$out/share/icons/hicolor/''${size}x''${size}/apps/superwhisper.png"
    done
    install -Dm0644 "$app/assets/linux-status/SuperwhisperTUI.ttf" \
      $out/share/fonts/truetype/SuperwhisperTUI.ttf
    install -Dm0644 -t $out/share/doc/superwhisper README.md licenses/*

    # The upstream desktop entry, with the store launcher.
    install -Dm0644 /dev/stdin $out/share/applications/com.superwhisper.Superwhisper.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Superwhisper
    Comment=Fast local and cloud dictation
    Exec=$out/bin/superwhisper settings --window
    Icon=superwhisper
    Terminal=false
    StartupWMClass=com.superwhisper.Superwhisper
    Categories=Utility;Accessibility;
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Local and cloud voice dictation for Wayland desktops";
    homepage = "https://superwhisper.com/linux";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames sources;
    mainProgram = "superwhisper";
  };
}
