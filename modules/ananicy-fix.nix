{ ... }:

# TEMPORARY — delete once nixpkgs ships an ananicy-cpp that builds.
#
# ananicy-cpp 1.2.0 uses std::memset, std::int32_t etc. without including
# <cstring> / <cstdint>. It only compiled because libc++ pulled those in
# transitively; the current toolchain no longer does, so the build fails
# file by file (argument.cpp, then backtrace.cpp, ...). nixpkgs has no patch
# and Hydra can't build it either, hence no cache hit anywhere.
#
# Prepend both headers to EVERY C++ translation unit under src/. Errors are
# reported per-TU, so covering all .cpp files also covers anything a header
# drags in. Deterministic — unlike -DCMAKE_CXX_FLAGS, which nixpkgs
# word-splits on spaces (CMake then chokes on the bare "-include").
# Only .cpp is touched, so the BPF C sources are unaffected.
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
