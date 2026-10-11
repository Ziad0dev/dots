# Secrets

SOPS files and private keys are kept locally and ignored by Git. Host configurations still refer to `secrets/<host>.yaml`, so restore the encrypted files from a private backup before building a host. At boot, [sops-nix](https://github.com/Mic92/sops-nix) decrypts declared values into `/run/secrets` (a ramfs, never the store). `modules/secrets.nix` wires this up behind `dots.secrets.enable`.

| File | Decrypted by | Edited by |
|---|---|---|
| `secrets/vm.yaml` | the `vm` host, with its local age identity | your GPG key |
| `secrets/nixos.yaml` | the desktop, with `/var/lib/sops-nix/key.txt` | your GPG key |

`.sops.yaml` contains public recipient information and creation rules. It is tracked so SOPS can select recipients; keep GPG and age private keys outside this public repo.

## Desktop secrets

The desktop currently declares the Restic password. Mullvad's WireGuard config can be added after generating a fresh file from the Mullvad account; `the-page` is deferred.

| Secret | Path |
|---|---|
| `restic-password` | `/etc/restic/password` |

The host age key is `/var/lib/sops-nix/key.txt`; its encrypted backup is stored in the password store at `dots/age-nixos`. `.sops.yaml` has the matching public age recipient and your GPG key as recipients for `secrets/nixos.yaml`.

To add Mullvad after generating a new WireGuard config, run `sops secrets/nixos.yaml` and add the config as a `mullvad-wg: |` block in the editor. Then declare its path in `hosts/nixos/configuration.nix`:

```nix
sops.secrets.mullvad-wg.path = "/etc/wireguard/mullvad.conf";
```

Keep the config out of chat and do not write a plaintext copy into the repo. Switch the system after declaring the secret; SOPS decrypts configured entries at boot.

## Rotating

- A recipient changed: edit `.sops.yaml`, then `sops updatekeys secrets/<host>.yaml`.
- A value changed: `sops secrets/<host>.yaml`, edit, save, switch.
- The VM test age key was committed to public history. Treat it as compromised and use only disposable test values until the recipient and local fixture are rotated. Removing files from the current tree does not erase their copies from old commits.
- A host key leaked: generate a new age key, update `.sops.yaml`, run `sops updatekeys`, and rotate every value in that file. Old ciphertext may remain in Git history and clones.
