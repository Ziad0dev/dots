{
  pkgs,
  inputs,
  system,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    zigpkgs."0.16.0"
    inputs.zls.packages.${system}.zls

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
