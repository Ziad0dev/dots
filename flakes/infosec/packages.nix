{ lib, pkgs }:
let
  # IDA 9.4's tools/tilib/tilib has overlapping PT_LOAD segments that make
  # patchelf 0.18+ abort while growing its RUNPATH. Patchelf 0.15.2 handles it.
  patchelf015 = pkgs.patchelf.overrideAttrs (_: {
    version = "0.15.2";
    src = pkgs.fetchurl {
      url = "https://github.com/NixOS/patchelf/releases/download/0.15.2/patchelf-0.15.2.tar.bz2";
      hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
    };
    doCheck = false;
  });
in
(import ../lib/toolkit.nix).mkPackages {
  inherit lib pkgs;
  names = import ./names.nix;
  overrides = {
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
        nativeBuildInputs = [ patchelf015 ] ++ (prev.nativeBuildInputs or [ ]);
        preFixup = (prev.preFixup or "") + ''
          export PATH=${patchelf015}/bin:$PATH
        '';
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
