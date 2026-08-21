{ config, lib, pkgs, ... }:

let
  base = config.boot.kernelPackages.nvidiaPackages.production;
in
{
  hardware.nvidia.package = lib.mkForce (
    base
    // {
      open = base.open.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
          pkgs.zstd
          pkgs.nukeReferences
        ];
        postFixup = (old.postFixup or "") + ''
          find $out/lib/modules -name '*.ko.zst' | while read -r f; do
            zstd -d --rm "$f"
            nuke-refs "''${f%.zst}"
            zstd -19 --rm "''${f%.zst}"
          done
        '';
      });
    }
  );
}
