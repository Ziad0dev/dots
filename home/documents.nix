{ pkgs, ... }:
# LaTeX + Typst + Zathura.
#
# Home layer rather than modules/: programs.zathura only exists in
# home-manager, and xdg.mimeApps likewise, so splitting the stack across two
# layers would buy nothing. Nothing here needs a system unit or root.
#
# Fonts are the deliberate exception — they live in hosts/nixos/configuration.nix
# so one fontconfig cache serves Typst, TeX, Zathura and everything else.
let
  # oxocarbon, matching config/hypr/colors.lua
  base00 = "#161616";
  base01 = "#262626";
  base02 = "#393939";
  base04 = "#dde1e6";
  base05 = "#f2f4f8";
  blue = "#33b1ff";
  purple = "#be95ff";
  pink = "#ee5396";

  # Inverse search. vimtex broadcasts to whichever running nvim already holds
  # the file, so this needs no --listen socket or servername bookkeeping.
  #
  # This goes through a script rather than being inlined into zathurarc:
  # girara's config parser has no escape for a double quote inside a quoted
  # value, so an inlined `nvim --headless -c "..."` terminates the string at
  # the inner quote and the %{line} / %{input} placeholders fall outside it.
  # Zathura then has nothing to substitute and <C-click> silently does nothing.
  # Three bare tokens sidestep the parser entirely.
  nvimSynctex = pkgs.writeShellScriptBin "nvim-synctex" ''
    exec nvim --headless -c "VimtexInverseSearch $1 '$2'"
  '';
in
{
  home.packages = with pkgs; [
    # TeX ---------------------------------------------------------------------
    texliveFull # ~6-7 GB closure; nix path-info -Sh nixpkgs#texliveFull
    texlab # completion/refs only — vimtex owns compilation

    # Typst -------------------------------------------------------------------
    typst
    tinymist # LSP + built-in preview server
    typstyle # formatter tinymist shells out to

    # PDF plumbing ------------------------------------------------------------
    poppler-utils # pdftotext, pdfinfo, pdfimages
    qpdf # lossless structural edits

    nvimSynctex # zathura's inverse-search hook; see the note above
  ];

  programs.zathura = {
    enable = true;
    # pkgs.zathura is already the wrapper carrying zathura_pdf_mupdf.
    # Do not also add zathura_pdf_poppler — two backends, one mimetype.
    package = pkgs.zathura;

    options = {
      selection-clipboard = "clipboard";
      adjust-open = "best-fit";
      statusbar-home-tilde = true;
      window-title-basename = true;
      database = "sqlite"; # remembers page position per document
      synctex = true;
      scroll-step = 80;
      smooth-scroll = true;

      default-bg = base00;
      default-fg = base05;
      statusbar-bg = base01;
      statusbar-fg = base04;
      inputbar-bg = base02;
      inputbar-fg = base05;
      notification-bg = base01;
      notification-fg = base05;
      notification-error-bg = pink;
      notification-error-fg = base00;
      notification-warning-bg = purple;
      notification-warning-fg = base00;
      completion-bg = base01;
      completion-fg = base05;
      completion-highlight-bg = blue;
      completion-highlight-fg = base00;
      highlight-color = purple;
      highlight-active-color = blue;
      index-bg = base00;
      index-fg = base05;
      index-active-bg = blue;
      index-active-fg = base00;

      # Dark page rendering; <C-r> toggles it back for figures and photos.
      recolor = true;
      recolor-lightcolor = base00;
      recolor-darkcolor = base05;
      recolor-keephue = true;
      recolor-reverse-video = true;
    };

    mappings = {
      "<C-r>" = "recolor";
      "u" = "scroll half-up";
      "d" = "scroll half-down";
      "D" = "toggle_page_mode";
      "r" = "reload";
      "R" = "rotate";
    };

    # Values with spaces or quotes go here: home-manager writes
    # `set <name> <value>` verbatim without adding quotes, so a bare string
    # containing a space produces an invalid zathurarc line.
    extraConfig = ''
      set font "FiraCode Nerd Font 11"
      set synctex-editor-command "nvim-synctex %{line} %{input}"
    '';
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/pdf" = [ "org.pwmt.zathura.desktop" ];
      "application/postscript" = [ "org.pwmt.zathura.desktop" ];
      "application/epub+zip" = [ "org.pwmt.zathura.desktop" ];
      "application/x-pdf" = [ "org.pwmt.zathura.desktop" ];
    };
  };

  # Keeps a bare `latexmk` behaving identically to the one vimtex drives.
  # -synctex=1 has to be on the $pdflatex line too, not just the CLI flags,
  # or forward search silently finds no .synctex.gz.
  home.file.".latexmkrc".text = ''
    $pdf_mode = 1;
    $postscript_mode = 0;
    $dvi_mode = 0;
    $pdflatex = 'pdflatex -synctex=1 -interaction=nonstopmode -file-line-error %O %S';
    $out_dir = 'build';
    $aux_dir = 'build';
    $clean_ext = 'synctex.gz bbl run.xml';
  '';
}
