{ pkgs, ... }:

{

  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  programs.lazygit.enable = true;
  programs.gh.enable = true;
  programs.bat.enable = true;

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  home.packages = with pkgs; [
    eza
    hyperfine
    tokei
    nixfmt
    statix
    deadnix
    devenv
  ];
}
