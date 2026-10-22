{ inputs }:

[
  inputs.zig-overlay.overlays.default
  inputs.obsidian-extensions.overlays.default
  inputs.millennium.overlays.default
  (final: _prev: {
    soulseek-rs = final.callPackage ../pkgs/soulseek-rs.nix { };
    caelestia-blobs = final.callPackage ../pkgs/caelestia-blobs { };
    google-sans-flex = final.callPackage ../pkgs/google-sans-flex { };
    rise-theme-fonts = final.callPackage ../pkgs/rise-theme-fonts { };
    sweet-gtk = final.callPackage ../pkgs/sweet-gtk { };
    papirus-tinted = final.callPackage ../pkgs/papirus-tinted { };
  })
  (final: prev: {
    feather =
      if prev.lib.functionArgs prev.feather.override ? boost186 then
        (prev.feather.override {
          boost186 = final.boost;
          protobuf = final.protobuf.override {
            abseil-cpp = final.abseil-cpp.override { cxxStandard = "17"; };
          };
        }).overrideAttrs
          (old: {
            cmakeFlags = builtins.filter (f: !(prev.lib.hasPrefix "-DProtobuf_" f)) old.cmakeFlags;
          })
      else
        prev.feather;
  })
  # nixpkgs ships a stale pnpm deps hash for 6.0.2. Only applies while upstream
  # still has the broken hash, so it goes inert once nixpkgs is fixed.
  (final: prev: {
    typescript-language-server =
      if
        prev.typescript-language-server.pnpmDeps.outputHash
        == "sha256-MUSxDMlbG21KSesGdEvqa2kEpuVfLlXRUX1qV/FGsSo="
      then
        prev.typescript-language-server.overrideAttrs (
          finalAttrs: _old: {
            pnpmDeps = final.fetchPnpmDeps {
              inherit (finalAttrs) pname version src;
              pnpm = final.pnpm_12;
              fetcherVersion = 4;
              hash = "sha256-xR/EF60lVBsITKgH7wCM2wHM46PFQevD51KfCENSUH4=";
            };
          }
        )
      else
        prev.typescript-language-server;
  })
  # pyopenjtalk-plus 0.4.1-post9 changed two TypeError messages without
  # updating the corresponding test expectations.
  (final: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (pyFinal: pyPrev: {
        pyopenjtalk-plus = pyPrev.pyopenjtalk-plus.overridePythonAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace tests/test_frontend.py \
              --replace-fail 'match="must be str"' 'match="Expected str"'
            sed -i '/^def test_make_label_validation_error_should_not_break_next_call():$/,/^def test_make_label_missing_field_should_not_break_next_call():$/s/match="Expected str"/match="NJD feature field must be str"/' \
              tests/test_frontend.py
          '';
        });
      })
    ];
  })
  # Calibre enables speech support but depends on speechd-minimal, which
  # removes the Python client API that Calibre imports at runtime.
  (final: prev:
    let
      # speechd sets strictDeps but only lists python in buildInputs, so
      # configure finds no interpreter and silently skips the bindings.
      speechdWithPython = (prev.speechd.override {
        python3Packages = final.python314Packages;
      }).overrideAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ final.python314Packages.python ];
      });
    in
    {
      calibre = prev.calibre.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          mkdir -p "$out/lib/calibre"
          cp -a ${speechdWithPython}/${final.python314Packages.python.sitePackages}/speechd \
            "$out/lib/calibre/"
        '';

        preInstallCheck = (old.preInstallCheck or "") + ''
          export PYTHONPATH="$out/lib/calibre''${PYTHONPATH:+:$PYTHONPATH}"
        '';

        preFixup = ''
          qtWrapperArgs+=(--prefix PYTHONPATH : "$out/lib/calibre")
        '' + (old.preFixup or "");
      });
    })
]
