{ lib, pkgs }:
(import ../lib/toolkit.nix).mkPackages {
  inherit lib pkgs;
  names = import ./names.nix;
  overrides = {
    # Cutter/rizin with the Ghidra decompiler and friends bundled in.
    # lowPrio: both bundles ship the same plugin files (lib/rizin/plugins,
    # rz_ghidra.pc); Cutter loads its own copies via its wrapper anyway
    cutter = lib.lowPrio (
      pkgs.cutter.withPlugins (
        ps: with ps; [
          rz-ghidra
          jsdec
          sigdb
        ]
      )
    );
    rizin = pkgs.rizin.withPlugins (
      ps: with ps; [
        rz-ghidra
        jsdec
        sigdb
      ]
    );
    # nixpkgs pins 9.3; Hex-Rays only serves the current release behind a
    # login, so pin the installer we have. requireFile: add it to the store
    # with `nix-store --add-fixed sha256 ida-free-pc_94_x64linux.run`
    ida-free = pkgs.ida-free.overrideAttrs (
      final: prev: {
        version = "9.4";
        # 9.4's ida binary links libXtst, which 9.3 didn't
        runtimeDependencies = prev.runtimeDependencies ++ [ pkgs.libxtst ];
        src = pkgs.requireFile {
          name = "ida-free-pc_94_x64linux.run";
          url = "https://my.hex-rays.com/dashboard/download-center/installers/release/${final.version}/ida-free";
          hash = "sha256-cbrrP7xElqMMm7Rd8Ikfg2ibmEAJ+S2GID3aKhVJq/g=";
        };
      }
    );
    # pwntools ships its own bin/checksec; the real checksec wins
    # (pwntools' stays reachable as `pwn checksec`)
    "python3Packages.pwntools" = lib.lowPrio pkgs.python3Packages.pwntools;
  };
}
