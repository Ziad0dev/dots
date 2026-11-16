{
  lib,
  stdenvNoCC,
  fetchurl,
}:

# Sweet, the GTK themes candy-icons is drawn for (Sweet-Dark for the candy
# theme, Sweet-mars for candy-mars). nixpkgs dropped `sweet` with
# gtk-engine-murrine (its GTK 2 side), so this ships only the GTK 3/4 parts
# of the upstream release.
let
  version = "6.0";
  variant =
    name: hash:
    fetchurl {
      url = "https://github.com/EliverLara/Sweet/releases/download/v${version}/${name}.tar.xz";
      inherit hash;
    };
in
stdenvNoCC.mkDerivation {
  pname = "sweet-gtk";
  inherit version;

  srcs = [
    (variant "Sweet-Dark-v40" "sha256-aYPjnOEZMN9mPvnhK3eoCm1ybUxKPqPSoOL+kwsZsG4=")
    (variant "Sweet-mars-v40" "sha256-AKTNa6FHlPr1ZqlK5QYZzXRiPb5Nmzw2lTSNcWAtMAg=")
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    for t in Sweet-*; do
      mkdir -p $out/share/themes/$t
      cp -r $t/{assets,gtk-3.0,gtk-4.0,index.theme} $out/share/themes/$t/
    done
    install -Dm644 Sweet-Dark-v40/LICENSE $out/share/licenses/sweet-gtk/LICENSE
    runHook postInstall
  '';

  meta = {
    description = "Sweet GTK 3/4 themes (Sweet-Dark, Sweet-mars)";
    homepage = "https://github.com/EliverLara/Sweet";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
