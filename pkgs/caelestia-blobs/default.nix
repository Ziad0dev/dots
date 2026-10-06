{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  qt6,
  spirv-tools,
}:

# Caelestia.Blobs only — see CMakeLists.txt. Built against the same qt6 as
# pkgs.quickshell, which a QML plugin has to match.
stdenv.mkDerivation {
  pname = "caelestia-blobs";
  version = "0-unstable-2026-10-05";

  src = fetchFromGitHub {
    owner = "caelestia-dots";
    repo = "shell";
    rev = "6f7ce62b7a6ff9e37b66526065643ca6e9d65783";
    hash = "sha256-QVHAZ9wvODj1I67THL8nRr1eDTf9OB6kwoAzf9ZBf8o=";
  };

  postPatch = ''
    cp ${./CMakeLists.txt} CMakeLists.txt
  '';

  nativeBuildInputs = [
    cmake
    ninja
    qt6.qtshadertools
    spirv-tools # qsb's OPTIMIZED pass
  ];
  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
  ];
  dontWrapQtApps = true;

  cmakeFlags = [ (lib.cmakeFeature "INSTALL_QMLDIR" qt6.qtbase.qtQmlPrefix) ];

  meta = {
    description = "Caelestia's SDF blob shapes as a standalone QML module (Caelestia.Blobs)";
    homepage = "https://github.com/caelestia-dots/shell";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
