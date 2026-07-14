# ⸸ reaper.nvim — oxocarbon edition

A modern Lua/lazy.nvim port of [vim.reaper](https://github.com/GideonWolfe/vim.reaper)'s
philosophy: hackable, fully-featured, rice-friendly. Oxocarbon theme, transparent.

## Layout

```
nvim/
├── init.lua                 entrypoint (requires config.*)
└── lua/
    ├── config/
    │   ├── options.lua      vim options + leader
    │   ├── keymaps.lua      global, non-plugin maps
    │   ├── autocmds.lua     yank-hl, restore cursor, close-with-q
    │   └── lazy.lua         lazy bootstrap + { import = "plugins" }
    └── plugins/
        ├── colorscheme.lua  oxocarbon, transparent (ColorScheme autocmd)
        ├── dashboard.lua     alpha skull homepage
        ├── treesitter.lua
        ├── telescope.lua
        ├── lsp.lua           native vim.lsp, no Mason
        ├── completion.lua    nvim-cmp + luasnip + latex snippets + autopairs
        ├── explorer.lua      neo-tree
        ├── git.lua           gitsigns + lazygit + fugitive
        ├── statusline.lua    lualine + bufferline
        ├── editing.lua       surround/comment/ibl/flash/neoscroll/which-key
        ├── ui.lua            zen-mode + twilight + aerial
        ├── terminal.lua      toggleterm
        └── markdown.lua      markdown-preview + table-mode
```

## Key bindings (leader = `Space`)

| Action                | Key            |
| --------------------- | -------------- |
| Exit insert           | `jk` / `kj`    |
| Find files / grep     | `<leader>ff` / `<leader>fg` |
| Recent / buffers      | `<leader>fr` / `<leader>fb` |
| Explorer              | `<leader>e` / `<C-n>` |
| Outline (aerial)      | `<leader>o`    |
| Zen mode              | `<leader>tz`   |
| Terminal (float)      | `<leader>tt` / `<C-\>` |
| LazyGit / fugitive    | `<leader>gg` / `<leader>gs` |
| Stage / reset hunk    | `<leader>hs` / `<leader>hr` |
| Next / prev hunk      | `]h` / `[h`    |
| Flash jump            | `s` / `S`      |
| Rename / code action  | `<leader>rn` / `<leader>ca` |
| Format                | `<leader>cf`   |
| Markdown preview      | `<leader>mp`   |
| Lazy menu             | `<leader>L`    |

LSP maps (`gd`, `gr`, `K`, etc.) attach per-buffer when a server connects.

## Required external tools

- **ripgrep** + **fd** — telescope grep/find
- **lazygit** — `<leader>gg`
- **git** — gitsigns/fugitive
- LSP servers (install via Nix, no Mason): `lua-language-server`, `pyright`,
  `typescript-language-server`, `rust-analyzer`, `nixd`. Servers whose binary is
  absent are silently skipped — add/remove in `lua/plugins/lsp.lua`.
- A Nerd Font for icons.

## Install

Drop the `nvim/` folder at `~/.config/nvim` (or symlink it from `~/dots`).
First launch bootstraps lazy.nvim and installs everything.
