{ pkgs, ... }:

let
  runtimeLibs =
    p: with p; [
      acl
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      bzip2
      cairo
      cups
      curl
      dbus
      expat
      fontconfig
      freetype
      fribidi
      gdk-pixbuf
      glib
      gtk3
      harfbuzz
      icu
      libdecor
      libdrm
      libgbm
      libglvnd
      libice
      libpulseaudio
      libsm
      libsodium
      libssh
      libunwind
      libusb1
      libuuid
      libx11
      libxcb
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxinerama
      libxkbcommon
      libxml2
      libxrandr
      libxrender
      libxscrnsaver
      libxslt
      libxtst
      nspr
      nss
      openssl
      pango
      pipewire
      stdenv.cc.cc
      systemd
      util-linux
      vulkan-loader
      wayland
      xz
      zlib
      zstd
    ];

  appimageRun = pkgs.appimage-run.override {
    extraPkgs = p: [
      p.libdecor
      p.pipewire
      p.libunwind
    ];
  };

  fhs = pkgs.buildFHSEnv {
    name = "fhs";
    targetPkgs =
      p:
      runtimeLibs p
      ++ (with p; [
        bashInteractive
        coreutils
        diffutils
        file
        findutils
        gawk
        gnugrep
        gnused
        gnutar
        gzip
        iana-etc
        less
        procps
        python3
        which
        xdg-utils
      ]);
    multiPkgs = runtimeLibs;
    runScript = "bash";
    profile = "export DOTS_FHS=1";
  };
in
{
  programs.appimage = {
    enable = true;
    binfmt = true;
    package = appimageRun;
  };

  programs.nix-ld = {
    enable = true;
    libraries = runtimeLibs pkgs;
  };

  environment.systemPackages = [
    fhs
    pkgs.distrobox
    pkgs.steam-run
  ];
}
