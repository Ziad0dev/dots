{ pkgs }:

let
  inherit (pkgs) fetchurl fetchFromGitHub;

  # The map viewer's libraries, pinned: it has to work with no network at all
  maplibre = fetchurl {
    url = "https://registry.npmjs.org/maplibre-gl/-/maplibre-gl-5.24.1.tgz";
    hash = "sha256-uE1/33+6WSL9P/+aknM5NsegO5kWWvxshPQcMRvb+p0=";
  };
  pmtilesJs = fetchurl {
    url = "https://registry.npmjs.org/pmtiles/-/pmtiles-4.5.0.tgz";
    hash = "sha256-I658V1V4rSTNV5N31pxGVQYx2iGebxeZl+ws87jJN+U=";
  };
  basemapsJs = fetchurl {
    url = "https://registry.npmjs.org/@protomaps/basemaps/-/basemaps-5.7.2.tgz";
    hash = "sha256-LV1BspzdI2T3CSrUOb2dFwtPOMvsiFjO++hND5gSXOY=";
  };
  # fonts (glyph ranges) and sprites for the Protomaps styles
  basemapsAssets = fetchFromGitHub {
    owner = "protomaps";
    repo = "basemaps-assets";
    rev = "028c18f713baecad011301ff7a69acc39bcc2ae7";
    hash = "sha256-P52xWPZr59voAumONX/n8g15xxqgqyXYIRoZmNSawAw=";
  };

  # place search for the map; nixpkgs' `photon` is an unrelated web crawler
  photonJar = fetchurl {
    url = "https://github.com/komoot/photon/releases/download/1.3.0/photon-1.3.0.jar";
    hash = "sha256-qJcHwAReSAeyoRgOEy5o4QjZmHCfSLbJS5im4oH1caU=";
  };

  python = pkgs.python3;
in
rec {
  # nixpkgs' valhalla links libsodium but leaves it out of its binaries'
  # RUNPATH, so none of them start ("libsodium.so.26: cannot open shared
  # object file"); point the loader at it
  valhalla = pkgs.symlinkJoin {
    name = "valhalla-${pkgs.valhalla.version}";
    paths = [ pkgs.valhalla ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in $out/bin/valhalla_*; do
        wrapProgram "$bin" --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.libsodium ]}
      done
    '';
  };

  offline-photon = pkgs.writeShellApplication {
    name = "offline-photon";
    text = ''
      # JAVA_OPTS holds several options: split on purpose
      # shellcheck disable=SC2086
      exec ${pkgs.jre_headless}/bin/java ''${JAVA_OPTS:-} -jar ${photonJar} "$@"
    '';
  };

  offline-sync = pkgs.writeShellApplication {
    name = "offline-sync";
    runtimeInputs =
      with pkgs;
      [
        aria2
        b3sum
        git
        kiwix-tools
        rsync
        # routing tiles and the place index for the map
        osmium-tool
        zstd
      ]
      ++ [
        valhalla
        offline-photon
      ];
    text = ''exec ${python}/bin/python3 ${./sync.py} "$@"'';
  };

  offline-library-tools = pkgs.writeShellApplication {
    name = "offline-library-tools";
    text = ''
      exec ${
        python.withPackages (ps: [
          ps.fastapi
          ps.uvicorn
        ])
      }/bin/python3 ${./library-tools.py} "$@"
    '';
  };

  offline-maps-viewer = pkgs.runCommand "offline-maps-viewer" { } ''
    mkdir -p $out/lib $out/assets
    tar -xzf ${maplibre} --strip-components=2 -C $out/lib package/dist/maplibre-gl.js package/dist/maplibre-gl.css
    tar -xzf ${pmtilesJs} --strip-components=2 -C $out/lib package/dist/pmtiles.js
    tar -xzf ${basemapsJs} --strip-components=2 -C $out/lib package/dist/basemaps.js
    cp -r ${basemapsAssets}/fonts ${basemapsAssets}/sprites $out/assets/
    cp ${./maps/index.html} $out/index.html
  '';

  offline-hub = pkgs.runCommand "offline-hub" { } ''
    mkdir -p $out
    cp ${./hub/index.html} $out/index.html
  '';
}
