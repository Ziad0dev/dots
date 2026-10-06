{ inputs }:

[
  inputs.zig-overlay.overlays.default
  inputs.obsidian-extensions.overlays.default
  (final: _prev: {
    soulseek-rs = final.callPackage ../pkgs/soulseek-rs.nix { };
    caelestia-blobs = final.callPackage ../pkgs/caelestia-blobs { };
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
]
