{
  pkgs,
  inputs,
  system,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    # Zig and ZLS are deferred until the pinned versions build together.

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
}
