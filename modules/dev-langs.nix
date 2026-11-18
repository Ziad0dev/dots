{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    zigpkgs."0.16.0"
    # nixpkgs' zls for the 0.16 series: prebuilt, and it finds the zig above
    # on PATH. The zls flake's build ran its test suite locally (with a
    # warm-up hack to stay under a test timeout) and carried a second copy
    # of Zig 0.16.0 in its closure.
    zls_0_16

    nixd
    lua-language-server

    clang_multi
    clang-tools
    lldb
    gdb
    mold
    ccache
    bear
    meson
    ninja
    valgrind
    cppcheck

    python313
    uv
    ruff
    pyright

    sbcl
    rlwrap
  ];

  programs.ccache = {
    enable = true;
    cacheDir = "/var/cache/ccache";
  };
  # the module's setgid nix-ccache stats helper is a perl script, which the
  # wrapper integrity check (ELF targets only) now rejects; stats via
  # `sudo ccache -d /var/cache/ccache -s` instead
  security.wrappers.nix-ccache.enable = false;
}
