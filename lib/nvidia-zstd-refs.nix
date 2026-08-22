{ pkgs }:

drv:
drv
// {
  open = drv.open.overrideAttrs (old: {
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
