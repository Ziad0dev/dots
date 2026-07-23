# emacs.nix — home-manager module
# Ownership split per the usual rule: HM owns the package set,
# ~/dots/emacs owns the config (symlinked out-of-store).
{ pkgs, config, ... }:
{
  programs.emacs = {
    enable = true;
    # Pure-GTK build = native Wayland. No XWayland blur on Hyprland.
    package = pkgs.emacs-pgtk;
    extraPackages = epkgs: with epkgs; [
      evil                 # you know why
      evil-collection      # evil bindings for sly, magit, dired, ...
      evil-escape          # jk/kj to escape, like your nvim setup
      sly                  # the Common Lisp IDE layer (slynk server is pure CL)
      paredit              # structural editing; parens become a non-issue
      rainbow-delimiters
      corfu                # completion-at-point UI, feeds off sly
      envrc                # per-buffer direnv -> sly launches the flake's sbcl
      magit                # you'll thank me later
      autothemer
    ];
  };

  # Daemon + emacsclient for instant startup.
  # Hyprland bind suggestion: bind = $mod, E, exec, emacsclient -c -a emacs
  services.emacs = {
    enable = true;
    client.enable = true;
  };

  # dots owns the actual config:
  xdg.configFile."emacs/init.el".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dots/emacs/init.el";

  # Required for the envrc glue (skip if already enabled elsewhere):
  # programs.direnv = {
  #   enable = true;
  #   nix-direnv.enable = true;
  # };
}
