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

- lazy.nvim, native `vim.lsp.config` / `vim.lsp.enable`. **No Mason** — language servers come from Nix, and each one is enabled only if its binary is on PATH (`lua_ls`, `pyright`, `ts_ls`, `rust_analyzer`, `nixd`, `zls`, `clangd`, `ruff`, `tinymist`, `texlab`). In a devshell, the project's server wins.
- Colours follow themectl live.
- **Local FIM**: llama.vim talks to `http://127.0.0.1:8012/infill` — `systemctl start llama-fim`. It conflicts with the chat-model units, so it's one or the other on the GPU.
- **Chat**: codecompanion via OpenRouter, key read with `secretspec get OPENROUTER_API_KEY`.
- Lisp: nvlime + vim-sexp. LaTeX: vimtex, with Zathura inverse search going through the `nvim-synctex` wrapper. Typst: tinymist preview.

### Emacs

`home/emacs.nix`: emacs-pgtk running as a daemon with `emacsclient` wired up. Evil (+ collection, escape), SLY for Common Lisp, paredit, rainbow-delimiters, corfu, envrc (picks up direnv), magit. `init.el` is a live link to `config/emacs/init.el`.

### VS Code

`programs.vscode` with a fixed extension set (nix-ide, Python/Pylance, rust-analyzer, Zig, TOML, errorlens, GitLens, direnv, vim) and `mutableExtensionsDir` so you can still try extensions ad hoc. **`settings.json` is owned by themectl** — it's the rendered `config/themes/_templates/vscode-settings.json.in`, so changes made in the settings UI are lost on the next theme switch. Edit the template.

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

## Agent VM

`nixosConfigurations.claude-vm` is a disposable QEMU guest for letting a coding agent run without permission prompts. It's built from `hosts/claude-vm/` and driven by `scripts/claude-vm.sh`.

```fish
~/dots/scripts/claude-vm.sh          # build + boot ephemeral (-snapshot): nothing written to disk survives
~/dots/scripts/claude-vm.sh persist  # boot keeping /data/vms/claude-vm.qcow2
~/dots/scripts/claude-vm.sh ssh      # ssh -p 2222 dev@localhost
~/dots/scripts/claude-vm.sh reset    # delete the disk image
~/dots/scripts/claude-vm.sh build    # build only
```

| | |
|---|---|
| Resources | 6 GiB RAM, 4 cores, 24 GiB disk, no graphics (serial console, `Ctrl-a x` to power off) |
| Share | host `/data/vms/share` ↔ guest `/mnt/work` (9p). The guest user is uid 1001, same as the host user, so ownership lines up |
| Ports | `127.0.0.1:2222` → ssh, `:5173` and `:3000` forwarded for dev servers |
| Guest | user `dev` / password `dev`, passwordless sudo, autologin, firewall off, writable store, flakes enabled, registry pinned to the host flake's nixpkgs |
| Tools | claude-code, git, gh, jujutsu, node 22, ripgrep, fd, jq, neovim, tmux, plus everything in `modules/dev-langs.nix` |
| Agent config | `~/.claude/settings.json` seeded from Nix on first boot (copied, not linked — the agent can edit it). `yolo` = `claude --dangerously-skip-permissions` |

Credentials from `claude` login land in the guest's home and vanish on an ephemeral boot — use `persist` to keep them. The guest's weak password is only reachable from the host's loopback.

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

Docker is rootless (`DOCKER_HOST` points at `/run/user/1001/docker.sock`) and not started at boot. Podman is installed alongside and is what distrobox uses.
