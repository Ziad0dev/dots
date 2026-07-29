{ pkgs, ... }:

# Home-manager side — imported from home.nix.
# (direnv/nix-direnv NOT here: home.nix already owns programs.direnv, and
# it already imports nix-index-database.homeModules.default, which the
# comma wiring below relies on. nix-direnv keeps GC roots in .direnv/, so
# nh clean won't collect deps of projects you're actively in.)

{
  # `, foo` runs foo straight from nixpkgs without installing it, using the
  # prebuilt weekly index from your existing nix-index-database input.
  # Also replaces command-not-found with "these packages provide it".
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  programs.fzf.enable = true;    # Ctrl-T files, Alt-C dirs, Ctrl-R history
  programs.zoxide.enable = true; # `z dots`, `z reduc` — frecency cd
  programs.lazygit.enable = true;
  programs.gh.enable = true;     # `gh auth login` once, then pr/issue/run from cli
  programs.bat.enable = true;

  # Alternative Ctrl-R: sqlite history with cwd + exit-code context.
  # Clashes with fzf's Ctrl-R — pick one.
  # programs.atuin = {
  #   enable = true;
  #   flags = [ "--disable-up-arrow" ]; # keep fish's prefix-search on ↑
  # };

  # If home.nix already has a git block, merge — delta is the point here:
  # syntax-highlighted, word-level diffs everywhere git shows one.
  programs.git = {
    enable = true;
    delta.enable = true;
  };

  home.packages = with pkgs; [
    eza # fd/ripgrep not repeated — configuration.nix carries them
    hyperfine # `hyperfine 'zig build'` — proper benchmarking
    tokei # line counts by language
    nixfmt
    statix # fmt / lint / dead-code keep it honest
    deadnix
  ];
}
