{
  pkgs,
  inputs,
  system,
  ...
}:

{
  environment.systemPackages = with pkgs; [

    zigpkgs.master
    inputs.zls.packages.${system}.zls

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
