# Development

## Where toolchains come from

Three layers, from most to least global:

| Layer | Where | What |
|---|---|---|
| System | `modules/dev-langs.nix` | Zig 0.16.0 + zls, nixd, lua-language-server, clang_multi / clang-tools / lldb / gdb / mold / ccache / bear / meson / ninja / valgrind / cppcheck, python313 + uv / ruff / pyright, SBCL (swank, alexandria) + rlwrap |
| User, every machine | `home/profiles/base.nix`, `home/dev-home.nix` | go, nodejs 22, lua + luarocks, tree-sitter, gnumake, cmake, pkg-config, sqlite, shellcheck, jujutsu; nix-index + `,`, fzf, zoxide, lazygit, gh, bat, delta, eza, hyperfine, tokei, nixfmt, devenv |
| User, desktop | `home/profiles/linux-desktop.nix` | Erlang 27 / Elixir / elixir-ls (OTP-matched), gcc |
| Per project | [templates](#project-templates) + direnv | pinned toolchain per repo |

The global layers are for editing and one-off scripts. Anything you'd hand to someone else gets a flake — templates pin their own nixpkgs, and `rustup` is deliberately absent because it shadows Nix-provided Rust inside devshells.

## Project templates

```fish
nix flake new -t ~/dots#zig ~/code/thing
cd ~/code/thing; git init; and git add -A; direnv allow
```

| Template | Gives you |
|---|---|
| `zig` | Zig 0.16.0 + matched zls; `.#edge` (0.17.0-dev + zls master) and `.#nightly` (master + master) |
| `rust` | rustc, cargo, rust-analyzer, rustfmt, clippy |
| `haskell` | `ghcWithPackages`, cabal, HLS (Clash extras commented) |
| `c` | clangStdenv, clangd, bear, meson, ninja, cmake, lldb; mold/gdb/valgrind on Linux; links with mold |
| `python` | python312.withPackages + ruff + pyright + uv; writes its own `.envrc` and a `.venv` on first entry |
| `lisp` | `sbcl.withPackages`, rlwrap |
| `beam` | Erlang 27, Elixir, elixir-ls |
| `typst` | typix: `nix build` → PDF, `nix run` → watch |
| `latex` | latexmk + reproducible `nix build`; `nix flake check` runs chktex |

Every template is multi-system (x86_64-linux, aarch64-linux, aarch64-darwin). Check them with `nix flake check ~/dots/templates/<name> --all-systems` — a plain `nix flake check` on the root flake never reaches them. The [Nix cheatsheet](nix-cheatsheet.md) has the full set of init/shell/lock commands and the gotchas.

**direnv**: `programs.direnv` with nix-direnv. Shells are cached in `.direnv/` with a GC root, and re-evaluated only when `flake.nix` or `flake.lock` change. `nix develop` on its own drops into bash; use direnv or `nix develop -c fish`.

## Editors

### Neovim

Documented in [`config/nvim/README.md`](../config/nvim/README.md). The short version:

- lazy.nvim, native `vim.lsp.config` / `vim.lsp.enable`. **No Mason** — language servers, formatters and debug adapters come from Nix (`home/nvim.nix` plus the system toolchains), and each server is enabled only if its binary is on PATH (`lua_ls`, `pyright`, `ts_ls`, `rust_analyzer`, `nixd`, `zls`, `clangd`, `ruff`, `tinymist`, `texlab`, `bashls`, `taplo`, `jsonls`, `yamlls`, `cssls`, `html`, `marksman`, `elixirls`, `hls`). In a devshell, the project's server wins. JSON/YAML get SchemaStore schemas.
- **Debugging**: nvim-dap + dap-ui. `lldb-dap` for C/C++/Rust/Zig, `debugpy-adapter` (a Nix wrapper) for Python — it picks up `$VIRTUAL_ENV` or `./.venv` — and `elixir-debug-adapter` for mix tasks. VS Code-style F5/F9/F10/F11 keys; `.vscode/launch.json` in a project is read too.
- **Formatting**: conform.nvim, format-on-save on by default (`<leader>uf` toggles, `<leader>uF` per buffer), skipped for Markdown and TeX. Falls back to the LSP formatter when a filetype has none listed.
- Trouble for the problems panel, diffview for history/merges, grug-far for project search & replace, persistence for per-directory sessions, direnv.vim so `:tcd` into a project loads its devshell, treesitter-context for sticky scroll.
- Colours follow themectl live.
- **Local FIM**: llama.vim talks to `http://127.0.0.1:8012/infill` — `systemctl start llama-fim`. It conflicts with the chat-model units, so it's one or the other on the GPU.
- **Chat**: codecompanion via OpenRouter, key read with `secretspec get OPENROUTER_API_KEY`.
- Lisp: nvlime + vim-sexp. LaTeX: vimtex, with Zathura inverse search going through the `nvim-synctex` wrapper. Typst: tinymist preview.

### Emacs

`home/emacs.nix`: emacs-pgtk running as a daemon with `emacsclient` wired up. Evil (+ collection, escape), SLY for Common Lisp, paredit, rainbow-delimiters, corfu, envrc (picks up direnv), magit. `init.el` is a live link to `config/emacs/init.el`.

## Tool flakes

`flakes/infosec` and `flakes/maths` are standalone flakes that group nixpkgs attributes into named sets.

| Flake | Sets | Systems |
|---|---|---|
| infosec | `core recon web binary pwn ad crack postex wireless forensics cloud mobile wordlists` | Linux only |
| maths | `core lean coq agda isabelle smt cas typeset viz julia python`, plus the `mathlib` devShell | Linux + aarch64-darwin |

Each set is exposed three ways — `packages.<set>` (a `buildEnv`), `devShells.<set>`, and as a module option — plus `all`, and an `audit` app that lists names which no longer resolve in nixpkgs. A name that stops resolving is dropped from its set instead of breaking evaluation, which is why `audit` exists.

```fish
nix shell ~/dots/flakes/infosec#web                  # stays in fish
nix develop ~/dots/flakes/maths#mathlib -c fish      # Lean + mathlib toolchain
nix run ~/dots/flakes/infosec#audit
```

As modules — `home/profiles/base.nix` imports both with `core` enabled:

```nix
zi.infosec = {
  enable = true;
  sets = [ "core" ];            # any of the set names; typo = eval error
  extraPackages = [ ];
};
```

From another flake:

```nix
inputs.dots-maths.url = "github:Ziad0dev/dots?dir=flakes/maths";
# NixOS:        imports = [ inputs.dots-maths.nixosModules.default ];
# home-manager: imports = [ inputs.dots-maths.homeManagerModules.default ];
```

Sets live in `names.nix`, one attribute path string per entry (`"python3Packages.pwntools"` works).

## Foreign binaries

`modules/foreign.nix` covers software that wasn't built for Nix. Pick by symptom:

| Situation | Use |
|---|---|
| Prebuilt ELF (release tarball, downloaded CLI, language-server binary) | Just run it — **nix-ld** provides the dynamic loader and a broad library set (GTK, X11/Wayland, Vulkan, PipeWire, NSS, OpenSSL, …) |
| AppImage | Run it directly — binfmt hands it to `appimage-run` (extended with libdecor, PipeWire, libunwind) |
| Installer or script that expects `/usr/lib`, `/bin/bash`, FHS layout | `fhs` — drops you into a bash with an FHS root built from the same library list; `DOTS_FHS=1` is set inside so your prompt/scripts can tell |
| Something Steam-runtime shaped | `steam-run <cmd>` |
| Needs a whole other distro's userland | `distrobox` (on Podman) |
| Python wheels with native code | the `python` template's `LD_LIBRARY_PATH` covers libstdc++, zlib, OpenSSL |

## Secrets

`secretspec.toml` at the repo root declares what secrets exist; values live in `pass` (GPG) or Bitwarden, never in the repo or the store.

| Secret | Required | Used by |
|---|---|---|
| `GOOGLE_BOOKS_API_KEY` | no | calibre-web metadata |
| `OPENROUTER_API_KEY` | no | codecompanion.nvim, the OpenRouter bar panel |

```fish
secretspec check
secretspec get OPENROUTER_API_KEY
```

`pass-secret-service` exposes the password store over the Secret Service API, so apps that want a keyring (libsecret) get `pass` instead of gnome-keyring.

## Containers

Docker is rootless (`DOCKER_HOST` points at `$XDG_RUNTIME_DIR/docker.sock`) and not started at boot. Podman is installed alongside and is what distrobox uses.
