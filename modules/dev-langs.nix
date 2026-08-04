{ pkgs, inputs, system, ... }:

# ── Language toolchains ───────────────────────────────────────────────────────
# Zig, C/C++, Python, Common Lisp. Owns the compilers, LSP servers, debuggers
# and build accelerators so nothing lands in a per-project shell that then
# disagrees with the editor.
#
# Zig/zls already came from configuration.nix (zig-overlay + inputs.zls). They
# are MOVED here, not duplicated — delete lines 202-203 of
# hosts/nixos/configuration.nix when wiring this in, along with the python313
# and sbcl lines (213-215, 221) and gcc (208). See the wiring notes.

{
  environment.systemPackages = with pkgs; [

    # ── Zig ──────────────────────────────────────────────────────────────────
    # master tracks the language; zls is version-matched from its own flake
    # input, which matters because zls breaks on stdlib churn otherwise.
    zigpkgs.master
    inputs.zls.packages.${system}.zls

    # ── C / C++ ──────────────────────────────────────────────────────────────
    # gcc stays as the system compiler; clang comes alongside it for clangd,
    # sanitizers and better diagnostics. Both on PATH is fine — clang doesn't
    # shadow gcc.
    clang_multi          # clang++ with 32-bit support (matters for Wine-adjacent work)
    clang-tools          # clangd, clang-format, clang-tidy
    lldb
    gdb
    mold                 # drop-in linker, dramatically faster than ld/lld at scale
    ccache
    bear                 # generates compile_commands.json for Make-based projects
    meson ninja          # cmake already in configuration.nix
    valgrind
    cppcheck

    # ── Python ───────────────────────────────────────────────────────────────
    # uv owns environments and interpreters; the system python313 exists only
    # as a scripting fallback. ruff replaces black+isort+flake8 outright.
    python313
    uv
    ruff
    pyright              # primary type checker / LSP — stable, complete
    # ty is Astral's Rust type checker: 10-100x faster, but still 0.0.x beta as
    # of mid-2026 with incomplete typing-spec coverage. Available in nixpkgs as
    # `ty` if you want to run it alongside pyright — do NOT make it the only
    # checker yet.
    # ty

    # ── Common Lisp ──────────────────────────────────────────────────────────
    # For linear-a.lisp / sigla-query.lisp. sbcl is the implementation; the
    # rest is the dependency and REPL story.
    # ocicl and qlot are both ABSENT from nixpkgs. The native route is
    # sbcl.withPackages, which pulls systems from the quicklisp-derived
    # sbclPackages set — declarative, and it means nvlime has swank on day one
    # instead of needing an imperative install.
    #
    # Add systems here as linear-a.lisp / sigla-query.lisp need them:
    #   nix repl -f '<nixpkgs>'  then  sbclPackages.<TAB>
    (sbcl.withPackages (ps: with ps; [
      swank              # the server nvlime/slime connect to
      alexandria         # de-facto stdlib supplement
    ]))
    rlwrap               # readline for a bare `sbcl` REPL
  ];

  # ── Build accelerators ─────────────────────────────────────────────────────
  # mold as the default linker for anything that respects the wrapper, and
  # ccache for repeated C/C++ builds. Both are opt-in per project via the
  # templates rather than forced globally — forcing mold system-wide has bitten
  # people on kernel-adjacent builds.

  # ccache store lives on the LUKS root; cap it so it can't eat the partition.
  programs.ccache = {
    enable = true;
    cacheDir = "/var/cache/ccache";
  };
}
