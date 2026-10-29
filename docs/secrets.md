# Secrets

The desktop's SOPS file, `secrets/nixos.yaml`, is tracked in this public repo as ciphertext; only the private keys stay out of it. Builds are pure: no `--impure`, no out-of-band file to restore before evaluating. Nix copies the ciphertext into the store; plaintext values and the age private key never enter it. At boot, [sops-nix](https://github.com/Mic92/sops-nix) decrypts declared values into `/run/secrets` (a ramfs, never the store). `modules/secrets.nix` wires this up behind `dots.secrets.enable`. The pre-commit hook refuses any tracked `secrets/*` file that is not SOPS-encrypted.

| File | Decrypted by | Edited by |
|---|---|---|
| `secrets/nixos.yaml` | the desktop, with `/var/lib/sops-nix/key.txt` | your GPG key |

`.sops.yaml` contains public recipient information and creation rules. It is tracked so SOPS can select recipients; keep GPG and age private keys outside this public repo.

## Desktop secrets

The desktop currently declares the Restic password. Mullvad's WireGuard config can be added after generating a fresh file from the Mullvad account; `the-page` is deferred.

| Secret | Path |
|---|---|
| `restic-password` | `/etc/restic/password` |

The host age key is `/var/lib/sops-nix/key.txt`; its encrypted backup is stored in the password store at `dots/age-nixos`. On an impermanent host the key is bind-mounted from `/persist`, and the installer restores it there. Keep an independent backup of the age key and the GPG key recovery material: the home Restic backup holds the password store, so it cannot be the only recovery copy. `.sops.yaml` has the matching public age recipient and your GPG key as recipients for the desktop file.

To add Mullvad after generating a new WireGuard config, run `sops secrets/nixos.yaml` and add the config as a `mullvad-wg: |` block in the editor. Then declare its path in `hosts/nixos/configuration.nix`:

```nix
sops.secrets.mullvad-wg.path = "/etc/wireguard/mullvad.conf";
```

Keep the config out of chat and do not write a plaintext copy into the repo. Run `nh os switch` after declaring the secret; SOPS decrypts configured entries at boot. The VM test host has no account password or SOPS data: it auto-logs in on its console and the installer test generates a per-run LUKS passphrase.

## Rotating

- A recipient changed: edit `.sops.yaml`, then `sops updatekeys secrets/nixos.yaml`.
- A value changed: `sops secrets/nixos.yaml`, edit, save, then switch with `nh os switch`.
- A host key leaked: generate a new age key, update `.sops.yaml`, run `sops updatekeys`, and rotate every value in that file. Old ciphertext may remain in Git history and clones.
