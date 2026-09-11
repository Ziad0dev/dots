# Nix cheatsheet — dots edition

Built against `Ziad0dev/dots@a4ccf72` (2026-09-11). All commands are fish syntax.

---

## 1. Start a project from a dots template

```fish
nix flake new -t ~/dots#rust ~/code/thing
cd ~/code/thing
git init; and git add -A
direnv allow
```

Already have the directory? `nix flake init -t ~/dots#rust` inside it (refuses to overwrite files that differ).

| Template  | Shell gives you | Notes |
|-----------|-----------------|-------|
| `zig`     | zig 0.16.0 + zls 0.16.0 (matched) | extra shells: `.#edge` = 0.17.0-dev.387 + zls master, `.#nightly` = zig master + zls master |
| `rust`    | rustc, cargo, rust-analyzer, rustfmt, clippy | nixpkgs toolchain, no rustup |
| `haskell` | `ghcWithPackages`, cabal, HLS | add libs inside `ghcWithPackages (ps: [ … ])` |
| `c`       | clangStdenv, clangd, bear, meson, ninja, cmake, lldb, pkg-config; mold/gdb/valgrind on Linux | links with mold; `bear -- make` regenerates `compile_commands.json` |
| `python`  | python312.withPackages, ruff, pyright, uv | **no `.envrc` shipped** — first `nix develop` writes it and builds `.venv` on the nix python. Nix libs go in `withPackages`, the rest via `uv pip install`. Gitignore `.venv` |
| `lisp`    | `sbcl.withPackages` (swank, alexandria), rlwrap | deps go in `sbcl.withPackages` |
| `beam`    | erlang 27, elixir, elixir-ls (OTP-matched) | |
| `typst`   | typst, tinymist, typstyle + typix scripts | `nix run` = watch, `nix build` → `result` **is** the PDF |
| `latex`   | texliveMedium + latexmk set, texlab, zathura | `nix build` → `result/main.pdf`; `nix flake check` runs chktex; `lmk` / `lmc` abbrevs |

Useful variations:

| Command | What |
|---|---|
| `nix flake show ~/dots` | list templates (+ everything else the flake exports) |
| `nix flake new -t github:Ziad0dev/dots#zig thing` | same, from a machine without the checkout |
| `nix flake show templates` | upstream NixOS/templates (`-t templates#go`, `#trivial`, …) |
| `nix flake init -t github:the-nix-way/dev-templates#go` | big third-party set for languages dots doesn't cover |
| `nix flake update` | right after init — templates copy their `flake.lock` (nixpkgs pinned 2026-08-23, zig 08-29) |

Pin a new project to exactly the nixpkgs your system is on (reuses what's already in the store instead of pulling a second nixpkgs world):

```fish
nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/(nixos-version --json | jq -r .nixpkgsRevision)
```

From scratch, same shape as the templates:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      eachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell { packages = with pkgs; [ ]; };
      });
      packages = eachSystem (pkgs: {
        default = pkgs.callPackage ./package.nix { };
      });
    };
}
```

---

## 2. Getting into the shell

| Command | What |
|---|---|
| `direnv allow` | load on `cd`, stays in fish — the default way |
| `echo 'use flake .#edge' > .envrc; direnv allow` | pick a named devShell (edit `.envrc` → must re-allow) |
| `echo 'use flake ~/dots/flakes/infosec#web' > .envrc` | pin a tool set to a directory, no project flake needed |
| `direnv reload` | force re-eval (nix-direnv already re-evals when `flake.nix`/`flake.lock` change) |
| `nix develop -c fish` | one-off; bare `nix develop` drops you into **bash** |
| `nix develop .#nightly -c fish` | named shell, one-off |
| `rm -rf .direnv` | drop the project's cached env + its GC root |

---

## 3. Ad-hoc tools, no project

| Command | What |
|---|---|
| `, tool args` | run anything once (comma + nix-index-database) |
| `nix shell nixpkgs#foo nixpkgs#bar` | temp PATH, stays in fish |
| `nix run nixpkgs#foo -- --flags` | run a package's main program |
| `nix-locate bin/foo` | which package ships this file (`-w` for whole-name match) |
| `nh search foo` | package search |
| `nh search options services.jellyfin` | NixOS / HM option search |
| `NIXPKGS_ALLOW_UNFREE=1 nix shell --impure nixpkgs#foo` | unfree — the registry `nixpkgs` doesn't see your `allowUnfree` |

`nixpkgs#…` resolves through the registry, which NixOS pins to the system's nixpkgs rev, so these are usually cache hits against what you already have.

---

## 4. Tool flakes (`~/dots/flakes`)

| Command | What |
|---|---|
| `nix shell ~/dots/flakes/infosec#web` | a set on PATH, stays in fish (sets are `buildEnv`s) |
| `nix develop ~/dots/flakes/infosec#web -c fish` | same, as a devShell |
| `nix develop ~/dots/flakes/maths#mathlib -c fish` | Lean/mathlib shell (elan + git/curl + gmp/zlib on `LD_LIBRARY_PATH`) — devShell only |
| `nix run ~/dots/flakes/infosec#audit` | names that no longer resolve in nixpkgs (`maths#audit` too) |
| `nix develop 'github:Ziad0dev/dots?dir=flakes/infosec#binary' -c fish` | from anywhere — keep the quotes |

- **infosec** (Linux only): `core recon web binary pwn ad crack postex wireless forensics cloud mobile wordlists all`
- **maths**: `core lean coq agda isabelle smt cas typeset viz julia python all` + `mathlib`
- `core` of both is already on your PATH through home-manager.

---

## 5. Inputs and the lock (inside a project)

| Command | What |
|---|---|
| `nix flake update` | bump every input |
| `nix flake update nixpkgs` | bump one input |
| `nix flake lock` | lock newly added inputs without bumping existing ones |
| `nix flake metadata` | inputs, locked revs, dates |
| `nix flake show` | outputs |
| `nix flake check` | eval + checks for this system; add `--all-systems` for all of them |
| `nix fmt` | only if the flake has a `formatter` output (dots does, templates don't) |

---

## 6. Build, run, debug

| Command | What |
|---|---|
| `nix build -L` | build `packages.default`, stream the log, output at `./result` |
| `nix build .#foo --keep-failed` | keep the failed build dir under `/tmp` to poke at |
| `nix run . -- args` | run the default app/package |
| `nix log .#foo` | log of the last build of that attr |
| `nix repl` → `:lf .` | flake in a repl (`:p` print deep, `:b` build) |
| `nix eval .#foo.version` | evaluate one attr |
| `nix path-info -Sh ./result` | closure size |
| `, nix-tree ./result` | browse the closure interactively |
| `nix why-depends ./result /nix/store/…-openssl-…` | who drags that in |
| `hash = lib.fakeHash;` → build → copy `got:` | the fetcher-hash dance |
| `nix flake prefetch github:owner/repo/<rev>` | SRI hash for `fetchFromGitHub` up front (no submodules) |

---

## 7. The system (`~/dots`)

```fish
cd ~/dots; git add -A; update
```

| Command | What |
|---|---|
| `update` | `nh os switch` |
| `upall` | `nh os switch -u` — bump all inputs, then switch |
| `nh os switch -U chaotic` | bump nixpkgs (it follows `chaotic/nixpkgs`; `nix flake update nixpkgs` is a no-op) |
| `flakeup` | `nix flake update --flake ~/dots` |
| `nh os test` | activate now, no boot entry |
| `nh os boot` | next boot only — kernel / driver bumps |
| `nh os build` | build + diff, touch nothing |
| `nh os switch -n` / `-a` | dry run / ask before activating |
| `nh os info` | list generations |
| `nh os rollback` | back one generation |
| `nh os repl` | system config in a repl |
| `nix eval ~/dots#nixosConfigurations.nixos.config.services.jellyfin.enable` | read any option |
| `nix eval ~/dots#nixosConfigurations.nixos.pkgs.nh.version` | a package as the system sees it |
| `nix fmt` | nixfmt-tree over the repo |
| `nh clean all --keep 3` | manual GC (the timer already runs `--keep 3 --keep-since 4d`) |

Eval errors — the real message is at the bottom:

```fish
nh os build --show-trace 2>&1 | tail -40
```

Other outputs:

| Command | What |
|---|---|
| `nh home switch ~/dots -c ziad0dev@linux` | bare Nix on Linux (`@linux-desktop`, `@aarch64-linux` too) |
| `nh darwin switch ~/dots -H mac` | nix-darwin |
| `~/dots/scripts/claude-vm.sh` | the sandbox VM |

Maintaining the templates:

```fish
for t in ~/dots/templates/*; nix flake update --flake $t; end
nix flake check ~/dots/templates/zig --all-systems
```

New template = `templates/<name>/{flake.nix,.envrc}`, `nix flake lock` inside it, register under `templates.<name>` in `flake.nix`, `git add -A`.

---

## 8. Fresh machine

```fish
git clone https://github.com/Ziad0dev/dots ~/dots

nixos-generate-config --show-hardware-config > ~/dots/hosts/nixos/hardware-configuration.nix
sudo nixos-rebuild switch --flake ~/dots#nixos

sudo nix run github:nix-darwin/nix-darwin/master#darwin-rebuild -- switch --flake ~/dots#mac

nix run github:nix-community/home-manager -- switch --flake ~/dots#ziad0dev@linux
```

Plain upstream Nix installs need `nix --extra-experimental-features 'nix-command flakes' …` until the config lands.

---

## Gotchas

- **Flakes in git only see tracked files.** New file → `git add` before nix, direnv, or nh will see it. The error is usually "path does not exist" or "not tracked by Git".
- `-t ~/dots` alone fails — there is no `default` template.
- Bare `nix develop` is bash. Use direnv or `-c fish`.
- Templates start on an old lock; `nix flake update` or the system-rev pin above.
- `nix shell nixpkgs#…` ignores your `allowUnfree`; needs the env var + `--impure`.
- `nh clean` reaps direnv GC roots older than `--keep-since` (4d), so a project untouched for a few days re-fetches its shell on next `cd`.
- `--show-trace`: pipe to `tail`, never `head`.
