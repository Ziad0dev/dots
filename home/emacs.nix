{ pkgs, config, ... }:
{
  programs.emacs = {
    enable = true;

    package = pkgs.emacs-pgtk;
    extraPackages =
      epkgs: with epkgs; [
        evil
        evil-collection
        evil-escape
        sly
        paredit
        rainbow-delimiters
        corfu
        envrc
        magit
        autothemer
      ];
  };

  services.emacs = {
    enable = true;
    client.enable = true;
  };

  xdg.configFile."emacs/init.el".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dots/config/emacs/init.el";

}
