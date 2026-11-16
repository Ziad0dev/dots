# ⸸ reaper.nvim — themectl edition

A modern Lua/lazy.nvim config. Colours are driven by `themectl`, so Neovim
follows the same palette as ghostty, quickshell, hyprland and the rest of the desktop.

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
    ├── pdf/                 PDF workbench: sign, annotate, redact, forms, ... (see "PDF")
    │   ├── init.lua         :Pdf command, tool menu, <leader>p keymaps
    │   ├── core.lua         runs dots-pdf / dots-pdfsign, picks the target PDF
    │   ├── sign.lua         certificate setup + signing flow
    │   └── buffer.lua       `nvim file.pdf` → selectable text view
    └── plugins/
        ├── colorscheme.lua  mini.base16 driven by config.theme
        ├── snacks.lua       dashboard, picker, explorer, terminal, zen, lazygit, indent
        ├── explorer.lua     oil (buffer-as-directory) + yazi + folder picker
        ├── treesitter.lua   + treesitter-context
        ├── lsp.lua          native vim.lsp, no Mason, SchemaStore
        ├── completion.lua   nvim-cmp + luasnip + latex snippets + autopairs
        ├── format.lua       conform (format on save)
        ├── dap.lua          nvim-dap + dap-ui + virtual text (lldb-dap, debugpy, elixir)
        ├── git.lua          gitsigns + fugitive + diffview
        ├── statusline.lua   lualine + bufferline
        ├── editing.lua      surround/ts-comments/flash/grug-far/which-key
        ├── workspace.lua    persistence sessions + direnv
        ├── ui.lua           aerial + trouble + todo-comments
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
| Debug: continue / stop     | `F5` / `S-F5`               |
| Debug: breakpoint          | `F9` / `<leader>Db`         |
| Debug: over / into / out   | `F10` / `F11` / `S-F11`     |
| Debug: UI / REPL / eval    | `<leader>Du` / `<leader>Dr` / `<leader>De` |
| Problems (workspace / buf) | `<leader>xx` / `<leader>xX` |
| Todos                      | `<leader>xt` / `<leader>ft` |
| Diff / file history        | `<leader>gd` / `<leader>gh` |
| Search & replace           | `<leader>rs` / `<leader>rS` |
| Restore session            | `<leader>qs` / `<leader>ql` |
| Format on save toggle      | `<leader>uf` / `<leader>uF` |
| Sticky context toggle      | `<leader>uc`                |
| Call hierarchy in / out    | `<leader>cs` / `<leader>cS` |

LSP maps (`gd`, `gr`, `K`, etc.) attach per-buffer when a server connects.
Commenting is Neovim's native `gc`/`gcc`, with `ts-comments.nvim` fixing
`commentstring` for embedded languages.

## PDF

Neovim can't render PDFs, so this is a thin UI over real engines: `scripts/dots-pdf.sh`
(qpdf, pdfcpu, ghostscript, poppler, ocrmypdf), `scripts/dots-pdf-annot.js`
(mupdf's JS API for annotations and true redaction) and `scripts/dots-pdfsign.sh`
(pyHanko). `home/documents.nix` installs them as `dots-pdf` and `dots-pdfsign`,
so they also work from any shell. Zathura stays the viewer.

`nvim file.pdf` opens the **text layer** (read-only) and launches the viewer.
`<CR>` reopens the viewer at the page under the cursor, `]]`/`[[` jump pages.
The target PDF is picked automatically: the PDF buffer, the oil entry under the
cursor, the file vimtex built from a `.tex`, or a picker. Edits never touch the
original: each tool writes `name.<tool>.pdf` beside it, and the viewer follows
the result, so tools chain (highlight → fill → sign).

`<leader>pp` (or `:Pdf`) opens the menu of everything; `:Pdf sign`, `:Pdf redact`, …
run one tool; `:Pdf raw <args>` goes straight to `dots-pdf`.

| Acrobat                    | Here                                              | Key (`<leader>p…`) |
| -------------------------- | ------------------------------------------------- | ------------------ |
| Certificate signature      | PAdES signature; visible box next to "Signature:", preset corner, exact box, or an existing field; certify mode; handwritten-image appearance | `s` (`k` setup, `K` image) |
| Validate signatures        | trust + integrity + modification check            | `V`                |
| Highlight / underline / strike | real annotations (visual-select text, then key) | `h` `H` `u` `x`    |
| Sticky note                | text annotation                                   | `n`                |
| Fill & Sign (typed text, ink image) | text / image placed after an anchor or at x,y | `f` `I`          |
| Redact                     | permanent: text is removed from the file          | `r`                |
| Fill form fields           | edit the exported JSON, `:w` writes a filled copy | `F`                |
| Flatten                    | bake forms/annotations into the page              | menu               |
| Combine / split / extract / delete / reorder / rotate / crop | qpdf / pdfcpu                  | `m` `e` `d` `o` `R`, menu |
| Page numbers, watermark    | pdfcpu stamps                                     | `N` `w`            |
| Compress / optimise        | ghostscript / qpdf                                | `c`, menu          |
| OCR scanned pages          | ocrmypdf (`DOTS_PDF_OCR_LANG`, default `eng`)     | `O`                |
| Password / permissions     | AES-256                                           | `l` `L`            |
| Properties, bookmarks, attachments | exiftool / pdfcpu                         | `M` `b` `a`        |
| Search, compare            | text search with jump-to-page; vimdiff of two PDFs | `g` `C`            |
| Export / import images, Office → PDF | pdftoppm, img2pdf, LibreOffice (if installed) | `T`, menu     |
| Freehand ink, drawn signature, shapes | hands off to Xournal++                | `G`                |
| Organise pages by drag & drop | hands off to PDF Arranger                      | `A`                |
| Edit existing text/images  | hands off to LibreOffice Draw (if installed)      | `E`                |

Coordinates are PDF points with the origin at the **bottom-left**. Signing:

```
dots-pdfsign init "Your Name" you@example.com   # once; or :Pdf sign offers it
dots-pdfsign image signature.png                # optional handwritten look
dots-pdfsign sign --at "Signature:" contract.pdf
dots-pdfsign verify contract.signed.pdf
```

Not Acrobat: a self-signed certificate proves integrity, not identity, so other
people see "unknown signer" until they trust `dots-pdfsign cert`; use
`dots-pdfsign import real.p12` for a CA-issued one (the passphrase is only saved
with `--store-pass`). There is no WYSIWYG click-to-place or in-place editing of
existing text — those are the Xournal++ / LibreOffice hand-offs. **Sign last.**
Annotating or filling an already-signed PDF keeps the signature cryptographically
intact (the signed bytes are untouched) but validators will list the later edits
as modifications; compressing, flattening or redacting rewrites the file and
drops the signatures altogether. Signing again just adds a further signature.

`snacks.image` is told to leave `pdf` alone (`lua/plugins/snacks.lua`) so it
doesn't replace the buffer with a one-page image stub.

## Required external tools

- **ripgrep** + **fd** — picker grep/find
- **lazygit** — `<leader>gg`
- **yazi** — `<leader>y`
- **git** — gitsigns/fugitive
- LSP servers (install via Nix, no Mason): `lua-language-server`, `pyright`,
  `ruff`, `nixd`, `zls`, `clangd`, `rust-analyzer`, `tinymist`, `texlab`,
  `typescript-language-server`, `bash-language-server`, `taplo`,
  `vscode-langservers-extracted`, `yaml-language-server`, `marksman`,
  `elixir-ls`, `haskell-language-server`. Servers whose binary is absent are
  silently skipped — add/remove in `lua/plugins/lsp.lua`.
- Formatters: `nixfmt`, `stylua`, `ruff`, `rustfmt`, `zig`, `clang-format`,
  `shfmt`, `taplo`, `typstyle`, `prettier`.
- Debug adapters: `lldb-dap` (from `lldb`), `debugpy-adapter`,
  `elixir-debug-adapter`. `home/nvim.nix` installs the ones not already in the
  system toolchains.
- PDF tools: `dots-pdf`, `dots-pdfsign` (installed by `home/documents.nix`
  together with `xournalpp` and `pdfarranger`), `zathura`. LibreOffice is
  optional (Office conversion, text editing).
- **direnv** — direnv.vim is skipped when it isn't installed
- A Nerd Font for icons.

## Install

Drop the `nvim/` folder at `~/.config/nvim` (or symlink it from `~/dots`).
First launch bootstraps lazy.nvim and installs everything.
