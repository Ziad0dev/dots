# Secrets

Secrets live in the repo, encrypted with [sops](https://github.com/getsops/sops), and are decrypted at boot by [sops-nix](https://github.com/Mic92/sops-nix) into `/run/secrets` (a ramfs, never the store). `modules/secrets.nix` wires it up behind `dots.secrets.enable`; each host declares its own `sops.secrets`.

| File | Decrypted by | Edited by |
|---|---|---|
| `secrets/vm.yaml` | the `vm` host, with the **test** key `hosts/vm/test-age-key.txt` (public on purpose) | your GPG key |
| `secrets/nixos.yaml` | the desktop, with `/var/lib/sops-nix/key.txt` | your GPG key |

`.sops.yaml` lists who can decrypt what. Your GPG key (the one `pass` uses) is a recipient everywhere, so `sops secrets/<host>.yaml` opens any of them for editing.

## Moving the desktop's hand-made files into sops

The desktop declares three secrets in `hosts/nixos/configuration.nix`, linked to the paths the modules already read, so nothing else changes:

| Secret | Path |
|---|---|
| `mullvad-wg` | `/etc/wireguard/mullvad.conf` |
| `restic-password` | `/etc/restic/password` |
| `the-page-env` | `/var/lib/secrets/the-page.env` |

1. **Host key.**
   ```fish
   sudo mkdir -p /var/lib/sops-nix
   sudo age-keygen -o /var/lib/sops-nix/key.txt
   sudo age-keygen -y /var/lib/sops-nix/key.txt   # the public half
   ```
   Back the private key up (it's the one thing a reinstall can't recreate), e.g. `sudo cat /var/lib/sops-nix/key.txt | pass insert -m dots/age-nixos`.
2. **Recipients.** In `.sops.yaml`, uncomment the `&nixos` key with that public half and the `secrets/nixos.yaml` rule.
3. **Encrypt.** Build the file from the current ones and encrypt it in place:
   ```fish
   begin
     printf 'mullvad-wg: |\n'; sudo sed 's/^/  /' /etc/wireguard/mullvad.conf
     printf 'restic-password: %s\n' (sudo cat /etc/restic/password)
     printf 'the-page-env: |\n'; sudo sed 's/^/  /' /var/lib/secrets/the-page.env
   end > secrets/nixos.yaml
   sops encrypt -i secrets/nixos.yaml
   git add secrets/nixos.yaml .sops.yaml
   ```
   Check with `sops decrypt secrets/nixos.yaml` before going on — the plaintext file must never be committed.
4. **Enable.** `dots.secrets.enable = true;` in the host, `nh os switch`. The three paths become symlinks into `/run/secrets`; the old files are replaced.

Adding one later: `sops secrets/nixos.yaml`, add the key, then `sops.secrets.<name>` (optionally with `path`, `owner`, `mode`) in the host.

## Rotating

- A recipient changed: edit `.sops.yaml`, then `sops updatekeys secrets/<host>.yaml`.
- A value changed: `sops secrets/<host>.yaml`, edit, save, switch.
- A host key leaked: new key (step 1), update `.sops.yaml`, `sops updatekeys`, and rotate every value in that file — the old ciphertext is in git history.
