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

    (sbcl.withPackages (
      ps: with ps; [
        swank
        alexandria
      ]
    ))
    rlwrap
  ];

  programs.ccache = {
    enable = true;
    cacheDir = "/var/cache/ccache";
  };
}
