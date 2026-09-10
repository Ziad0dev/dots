{ ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      ananicy-cpp = prev.ananicy-cpp.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          find src -name '*.cpp' -o -name '*.cc' | while read -r f; do
            grep -q '^#include <cstring>' "$f" || \
              sed -i '1i #include <cstring>\n#include <cstdint>' "$f"
          done
        '';
      });
    })
  ];
}
