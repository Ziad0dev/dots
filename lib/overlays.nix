{ inputs }:

[
  inputs.zig-overlay.overlays.default
  inputs.obsidian-extensions.overlays.default
  (final: _prev: {
    soulseek-rs = final.callPackage ../pkgs/soulseek-rs.nix { };
  })
]
