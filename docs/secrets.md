# Secrets

Encrypted SOPS files and private keys are kept outside this public repo. The desktop file lives at `~/.local/share/dots/secrets/nixos.yaml`; restore it from a private backup before building the desktop and keep it mode `0600`. Use `--impure` for desktop builds. Nix copies the encrypted ciphertext into the store so sops-nix can validate it; the age private key stays outside the store. At boot, [sops-nix](https://github.com/Mic92/sops-nix) decrypts declared values into `/run/secrets` (a ramfs, never the store). `modules/secrets.nix` wires this up behind `dots.secrets.enable`.

| File | Decrypted by | Edited by |
|---|---|---|
| `~/.local/share/dots/secrets/nixos.yaml` | the desktop, with `/var/lib/sops-nix/key.txt` | your GPG key |

`.sops.yaml` contains public recipient information and creation rules. It is tracked so SOPS can select recipients; keep GPG and age private keys outside this public repo.

## Desktop secrets

The desktop currently declares the Restic password. Mullvad's WireGuard config can be added after generating a fresh file from the Mullvad account; `the-page` is deferred.

| Secret | Path |
|---|---|
| `restic-password` | `/etc/restic/password` |

The host age key is `/var/lib/sops-nix/key.txt`; its encrypted backup is stored in the password store at `dots/age-nixos`. `.sops.yaml` has the matching public age recipient and your GPG key as recipients for the desktop file.

To add Mullvad after generating a new WireGuard config, run `sops "$HOME/.local/share/dots/secrets/nixos.yaml"` and add the config as a `mullvad-wg: |` block in the editor. Then declare its path in `hosts/nixos/configuration.nix`:

```nix
sops.secrets.mullvad-wg.path = "/etc/wireguard/mullvad.conf";
```

Keep the config out of chat and do not write a plaintext copy into the repo. Run `nh os switch --impure` after declaring the secret; SOPS decrypts configured entries at boot.

## Rotating

- A recipient changed: edit `.sops.yaml`, then `sops updatekeys "$HOME/.local/share/dots/secrets/nixos.yaml"`.
- A value changed: `sops "$HOME/.local/share/dots/secrets/nixos.yaml"`, edit, save, then switch with `nh os switch --impure`.
- The old VM test age key and fixture were committed to public history. The VM host no longer uses SOPS; that fixture contained disposable test data only. Removing files from the current tree does not erase their copies from old commits.
- A host key leaked: generate a new age key, update `.sops.yaml`, run `sops updatekeys`, and rotate every value in that file. Old ciphertext may remain in Git history and clones.
