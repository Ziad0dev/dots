{
  lib,
  stdenvNoCC,
  fetchurl,
}:

# Google Sans Flex, the variable font (GRAD ROND opsz slnt wdth wght) from
# google/fonts. Not in nixpkgs' google-fonts snapshot yet.
let
  rev = "a0e3dbcdc3a3ecfafff3f071159ae0221628922d";
  base = "https://raw.githubusercontent.com/google/fonts/${rev}/ofl/googlesansflex";
in
stdenvNoCC.mkDerivation {
  pname = "google-sans-flex";
  version = "0-unstable-2026-10-06";

  srcs = [
    (fetchurl {
      name = "GoogleSansFlex.ttf";
      url = "${base}/GoogleSansFlex%5BGRAD%2CROND%2Copsz%2Cslnt%2Cwdth%2Cwght%5D.ttf";
      hash = "sha256-wxpIL77L8uB+aJATTSAHhyOq33Msm5xsmkT4b4Jltv4=";
    })
    (fetchurl {
      url = "${base}/OFL.txt";
      hash = "sha256-/BPWn2PjbShLbjg9TRRj2K1ATwqgZeV8+WElLVEGMTc=";
    })
  ];

  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    for f in $srcs; do
      case $f in
        *.ttf) install -Dm644 $f $out/share/fonts/truetype/GoogleSansFlex.ttf ;;
        *) install -Dm644 $f $out/share/licenses/google-sans-flex/OFL.txt ;;
      esac
    done
    runHook postInstall
  '';

  meta = {
    description = "Google Sans Flex variable font";
    homepage = "https://github.com/googlefonts/googlesans-flex";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
