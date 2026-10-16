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
]
