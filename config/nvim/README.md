# ⸸ reaper.nvim — themectl edition

A modern Lua/lazy.nvim config. Colours are driven by `themectl`, so Neovim
follows the same palette as ghostty, waybar, dunst, rofi, hyprland and hyprlock.

## Layout

```
nvim/
├── init.lua                 entrypoint (requires config.*)
├── colors/
│   └── dots.lua             the colorscheme — applies the themectl palette
└── lua/
    ├── config/
    │   ├── options.lua      vim options + leader
    │   ├── keymaps.lua      global, non-plugin maps
    │   ├── autocmds.lua     yank-hl, restore cursor, mkdir-on-save, close-with-q
    │   ├── theme.lua        reads ~/.local/state/dots/theme/nvim.lua, hot-reloads
    │   └── lazy.lua         lazy bootstrap + { import = "plugins" }
    └── plugins/
        ├── colorscheme.lua  mini.base16 driven by config.theme
        ├── snacks.lua       dashboard, picker, explorer, terminal, zen, lazygit, indent
        ├── explorer.lua     oil (buffer-as-directory) + yazi + folder picker
        ├── treesitter.lua
        ├── lsp.lua          native vim.lsp, no Mason
        ├── completion.lua   nvim-cmp + luasnip + latex snippets + autopairs
        ├── git.lua          gitsigns + fugitive
        ├── statusline.lua   lualine + bufferline
        ├── editing.lua      surround/ts-comments/flash/which-key
        ├── ui.lua           aerial
        ├── lisp.lua         nvlime + vim-sexp + rainbow-delimiters
        ├── llm.lua          llama.vim FIM + codecompanion
        ├── tex.lua          vimtex
        ├── typst.lua        tinymist preview
        └── markdown.lua     markdown-preview + table-mode
```

## Theming

`themectl set <name>` renders `config/themes/_templates/nvim.lua.in` into
`~/.local/state/dots/theme/nvim.lua`. Every running Neovim watches that
directory with `fs_event` and re-applies the palette in place — no restart.

- `:DotsThemeReload` — re-read the palette by hand
- `:DotsThemeToggleTransparency` / `<leader>ut` — toggle the transparent background
- Without the state file (fresh clone, macOS, a box with no themectl) it falls
  back to oxocarbon.

Palettes with a degenerate base16 ramp (several have `base03 == base04 == base05`)
are repaired in `config/theme.lua` using the `dim`/`muted`/`surface` values
themectl derives.

## Key bindings (leader = `Space`)

| Action                     | Key                         |
| -------------------------- | --------------------------- |
| Exit insert                | `jk` / `kj`                 |
| Find files / grep          | `<leader>ff` / `<leader>fg` |
| Recent / buffers           | `<leader>fr` / `<leader>fb` |
| Symbols (doc / workspace)  | `<leader>fs` / `<leader>fS` |
| Undo tree                  | `<leader>fu`                |
| Explorer                   | `<leader>e` / `<C-n>`       |
| Explorer at file's folder  | `<leader>fF`                |
| Open folder as root        | `<leader>fp`                |
| Parent directory (oil)     | `-` / `<leader>-`           |
| Yazi (file / cwd)          | `<leader>y` / `<leader>Y`   |
| Outline (aerial)           | `<leader>o`                 |
| Zen mode / zoom            | `<leader>tz` / `<leader>tZ` |
| Terminal (float)           | `<leader>tt` / `<C-\>`      |
| Scratch buffer             | `<leader>.`                 |
| LazyGit / fugitive         | `<leader>gg` / `<leader>gs` |
| Stage / reset hunk         | `<leader>hs` / `<leader>hr` |
| Next / prev hunk           | `]h` / `[h`                 |
| Next / prev reference      | `]]` / `[[`                 |
| Flash jump                 | `s` / `S`                   |
| Rename / code action       | `<leader>rn` / `<leader>ca` |
| Rename file                | `<leader>rf`                |
| Format                     | `<leader>cf`                |
| Toggle inlay hints         | `<leader>uh`                |
| Markdown preview           | `<leader>mp`                |
| Lazy menu                  | `<leader>L`                 |

LSP maps (`gd`, `gr`, `K`, etc.) attach per-buffer when a server connects.
Commenting is Neovim's native `gc`/`gcc`, with `ts-comments.nvim` fixing
`commentstring` for embedded languages.

## Required external tools

- **ripgrep** + **fd** — picker grep/find
- **lazygit** — `<leader>gg`
- **yazi** — `<leader>y`
- **git** — gitsigns/fugitive
- LSP servers (install via Nix, no Mason): `lua-language-server`, `pyright`,
  `ruff`, `nixd`, `zls`, `clangd`, `rust-analyzer`, `tinymist`, `texlab`,
  `typescript-language-server`. Servers whose binary is absent are silently
  skipped — add/remove in `lua/plugins/lsp.lua`.
- **nixfmt** — nixd formatting is wired to it
- A Nerd Font for icons.

## Install

Drop the `nvim/` folder at `~/.config/nvim` (or symlink it from `~/dots`).
First launch bootstraps lazy.nvim and installs everything.
