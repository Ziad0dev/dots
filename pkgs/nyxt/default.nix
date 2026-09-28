{
  lib,
  stdenv,
  fetchFromGitHub,
  writeText,
  buildNpmPackage,
  electron,
  makeWrapper,
  pkg-config,
  sbcl,
  libfixposix,
  openssl,
  sqlite,
  enchant,
  xdg-utils,
  xclip,
  wl-clipboard,
}:

let
  version = "4.0.0";

  src = fetchFromGitHub {
    owner = "atlas-engineer";
    repo = "nyxt";
    tag = version;
    fetchSubmodules = true;
    gitConfigFile = writeText "nyxt-submodules.gitconfig" ''
      [url "https://codeberg.org/pcostanza/closer-mop"]
        insteadOf = https://github.com/pcostanza/closer-mop
    '';
    hash = "sha256-QG2wCMW/Vs2qBxsoqHSkxv7NQDgKL1c5+CA4TG7MTI0=";
  };

  electron-server = buildNpmPackage {
    pname = "cl-electron-server";
    inherit version src;
    sourceRoot = "${src.name}/_build/cl-electron";

    patches = [ ./cl-electron-nan-2.29.patch ];

    npmDepsHash = "sha256-eMoCAk4ZM75r+zdHsRKQkRLeeOJKymtWz/1lzyiVkBM=";
    npmInstallFlags = [ "--omit=dev" ];
    npmRebuildFlags = [ "--ignore-scripts" ];

    buildPhase = ''
      runHook preBuild
      npm rebuild synchronous-socket --nodedir=${electron.headers}
      runHook postBuild
    '';

    postInstall = ''
      pushd $out/lib/node_modules/cl-electron-server/node_modules
      rm -rf electron .bin/electron
      find synchronous-socket/build -mindepth 1 -maxdepth 1 ! -name Release -exec rm -rf {} +
      find synchronous-socket/build/Release -mindepth 1 -maxdepth 1 ! -name SynchronousSocket.node -exec rm -rf {} +
      popd
    '';
  };

  serverDir = "${electron-server}/lib/node_modules/cl-electron-server";
  baseString = s: "#.(coerce \"${s}\" 'simple-base-string)";
  yieldIndent = "\n                           (yield char)\n";

  runtimeLibs = [
    openssl
    sqlite
    libfixposix
    enchant
  ];
in
stdenv.mkDerivation {
  pname = "nyxt";
  inherit version src;

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    sbcl
    libfixposix
  ];

  env = {
    LD_LIBRARY_PATH = lib.makeLibraryPath runtimeLibs;
    NYXT_RENDERER = "electron";
    NYXT_VERSION = version;
  };

  postPatch = ''
    substituteInPlace _build/cl-electron/source/core.lisp \
      --replace-fail '(asdf:system-relative-pathname :cl-electron "source/server.js")' \
        ${lib.escapeShellArg "(pathname ${baseString "${serverDir}/source/server.js"})"} \
      --replace-fail '(list "npm" "run" "start" "--")' \
        ${lib.escapeShellArg "(list ${baseString (lib.getExe electron)})"} \
      --replace-fail '(asdf:system-source-directory :cl-electron)' \
        ${lib.escapeShellArg "(pathname ${baseString "${serverDir}/"})"}

    substituteInPlace _build/named-readtables/src/cruft.lisp \
      --replace-fail ${lib.escapeShellArg "(if reader-fn${yieldIndent}"} \
        ${lib.escapeShellArg "(if (and reader-fn (not (eql reader-fn 0)))${yieldIndent}"}
  '';

  postConfigure = ''
    export CL_SOURCE_REGISTRY="$(pwd)/_build//"
    export ASDF_OUTPUT_TRANSLATIONS="$(pwd):$(pwd)"
    export PREFIX="$out"
  '';

  makeFlags = [
    "all"
    "NYXT_SUBMODULES=false"
    "NODE_SETUP=false"
  ];

  installPhase = ''
    runHook preInstall
    sbcl --dynamic-space-size 3072 --noinform --no-userinit --non-interactive \
      --eval '(require "asdf")' \
      --eval "(asdf:load-asd \"$(pwd)/libraries/nasdf/nasdf.asd\")" \
      --eval "(asdf:load-asd \"$(pwd)/nyxt.asd\")" \
      --eval '(asdf:load-system :nyxt/electron-application)' \
      --eval '(asdf:make :nyxt/install)' \
      --eval '(uiop:quit 0)'
    runHook postInstall
  '';

  postInstall = ''
    wrapProgram $out/bin/nyxt \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --prefix PATH : ${
        lib.makeBinPath [
          xdg-utils
          xclip
          wl-clipboard
        ]
      }
  '';

  dontStrip = true;

  passthru = { inherit electron-server; };

  meta = {
    description = "Infinitely extensible web-browser (with Lisp development files using the Electron platform port)";
    mainProgram = "nyxt";
    homepage = "https://nyxt.atlas.engineer";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
