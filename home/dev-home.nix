{ pkgs, ... }:

{

  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  programs.lazygit.enable = true;
  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
  };
  programs.bat.enable = true;

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  home.packages = with pkgs; [
    abtop
    eza
    hyperfine
    tokei
    nixfmt
    devenv
  ];
}
