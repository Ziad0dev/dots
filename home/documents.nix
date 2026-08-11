{ pkgs, ... }:

let

  base00 = "#161616";
  base01 = "#262626";
  base02 = "#393939";
  base04 = "#dde1e6";
  base05 = "#f2f4f8";
  blue = "#33b1ff";
  purple = "#be95ff";
  pink = "#ee5396";

  nvimSynctex = pkgs.writeShellScriptBin "nvim-synctex" ''
    exec nvim --headless -c "VimtexInverseSearch $1 '$2'"
  '';
in
{
  home.packages = with pkgs; [

    texliveFull
    texlab

    typst
    tinymist
    typstyle

    poppler-utils
    qpdf

    nvimSynctex
  ];

  programs.zathura = {
    enable = true;

    package = pkgs.zathura;

    options = {
      selection-clipboard = "clipboard";
      adjust-open = "best-fit";
      statusbar-home-tilde = true;
      window-title-basename = true;
      database = "sqlite";
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

      "x-scheme-handler/http" = [ "zen-beta.desktop" ];
      "x-scheme-handler/https" = [ "zen-beta.desktop" ];
      "text/html" = [ "zen-beta.desktop" ];
      "x-scheme-handler/discord" = [ "vesktop.desktop" ];
    };
  };

  xdg.configFile."mimeapps.list".force = true;

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
