{
  pkgs,
  inputs,
  system,
  ...
}:

let
  zls = inputs.zls.packages.${system}.zls.overrideAttrs (old: {
    preCheck = (old.preCheck or "") + ''
      # Zig lazily compiles translate-c on first use; warm the test cache so
      # ZLS's cimport test stays within its 90-second timeout.
      mkdir -p .zig-cache/zls
      printf 'void zls_check_warmup(int);\n' > .translate-c-warmup.h
      zig translate-c \
        --zig-lib-dir ${pkgs.zigpkgs."0.16.0"}/lib \
        --cache-dir .zig-cache/zls \
        --global-cache-dir .zig-cache/zls \
        -lc .translate-c-warmup.h > /dev/null
      rm .translate-c-warmup.h
    '';
  });
in
{
  environment.systemPackages = with pkgs; [
    zigpkgs."0.16.0"
    zls

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
