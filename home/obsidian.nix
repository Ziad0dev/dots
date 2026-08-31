{ config, pkgs, ... }:

{
  programs.obsidian = {
    enable = true;
    cli.enable = true;

    vaults.notes.target = "Documents/notes";

    defaultSettings = {
      app = {
        alwaysUpdateLinks = true;
        attachmentFolderPath = "assets";
        defaultViewMode = "source";
        livePreview = true;
        newLinkFormat = "relative";
        promptDelete = false;
        readableLineLength = true;
        showLineNumber = true;
        spellcheck = true;
        strictLineBreaks = false;
        tabSize = 2;
        useMarkdownLinks = false;
        vimMode = true;
      };

      appearance = {
        accentColor = "#ee5396";
        baseFontSize = 15;
        interfaceFontFamily = "FiraCode Nerd Font";
        monospaceFontFamily = "JetBrainsMono Nerd Font";
        textFontFamily = "FiraCode Nerd Font";
        theme = "obsidian";
        translucency = false;
      };

      corePlugins = [
        "backlink"
        "bookmarks"
        "canvas"
        "command-palette"
        "editor-status"
        "file-explorer"
        "file-recovery"
        "global-search"
        "graph"
        "outgoing-link"
        "outline"
        "page-preview"
        "properties"
        "switcher"
        "tag-pane"
        "word-count"
        {
          name = "daily-notes";
          settings = {
            folder = "journal";
            format = "YYYY-MM-DD";
            template = "templates/daily.md";
          };
        }
        {
          name = "templates";
          settings.folder = "templates";
        }
        {
          name = "note-composer";
          settings.template = "";
        }
      ];

      communityPlugins = with pkgs.obsidianPlugins; [
        dataview
        obsidian-git
        obsidian-style-settings
        obsidian-vimrc-support
        omnisearch
        table-editor-obsidian
        templater-obsidian
        obsidian-tasks-plugin
        obsidian-linter
        obsidian-latex-suite
        obsidian-outliner
        cmdr
        recent-files-obsidian
        obsidian-excalidraw-plugin
      ];

      themes = [
        {
          pkg = pkgs.obsidianThemes.anuppuccin;
          enable = true;
        }
        {
          pkg = pkgs.obsidianThemes.kanagawa;
          enable = false;
        }
        {
          pkg = pkgs.obsidianThemes.flexoki;
          enable = false;
        }
      ];

      cssSnippets = [
        {
          name = "oxocarbon";
          enable = true;
          source = ./obsidian/oxocarbon.css;
        }
      ];

      hotkeys = {
        "command-palette:open" = [
          {
            modifiers = [ "Mod" ];
            key = "P";
          }
        ];
        "switcher:open" = [
          {
            modifiers = [ "Mod" ];
            key = "O";
          }
        ];
        "global-search:open" = [
          {
            modifiers = [
              "Mod"
              "Shift"
            ];
            key = "F";
          }
        ];
        "graph:open" = [
          {
            modifiers = [
              "Mod"
              "Shift"
            ];
            key = "G";
          }
        ];
        "daily-notes" = [
          {
            modifiers = [
              "Mod"
              "Shift"
            ];
            key = "D";
          }
        ];
        "editor:toggle-source" = [
          {
            modifiers = [ "Mod" ];
            key = "E";
          }
        ];
        "workspace:split-vertical" = [
          {
            modifiers = [ "Mod" ];
            key = "\\";
          }
        ];
      };
    };
  };

  home.file."Documents/notes/.obsidian/vimrc".text = ''
    set clipboard=unnamed
    imap jk <Esc>
    exmap back obcommand app:go-back
    exmap forward obcommand app:go-forward
    nmap <C-o> :back
    nmap <C-i> :forward
    nmap gd :obcommand editor:follow-link
  '';

  xdg.desktopEntries.obsidian = {
    name = "Obsidian";
    exec = "obsidian --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations %U";
    icon = "obsidian";
    terminal = false;
    categories = [
      "Office"
      "Utility"
    ];
    mimeType = [ "x-scheme-handler/obsidian" ];
  };
}
