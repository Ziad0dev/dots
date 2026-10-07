# Secure Boot

`modules/secureboot.nix` adds [lanzaboote](https://github.com/nix-community/lanzaboote)
(pinned to a release tag in `flake.nix`): systemd-boot's signed stub and signed
unified kernel images, with your own keys in `/var/lib/sbctl`. It is off until
`dots.secureBoot.enable = true;` in `hosts/nixos/configuration.nix`, and `sbctl`
is installed either way.

The disks are already LUKS-encrypted; Secure Boot adds that only boot files you
signed will run, so nobody can swap the kernel or initrd on the unencrypted
`/boot` to capture the passphrase.

The cachyos kernel doesn't force lockdown under Secure Boot
(`LOCK_DOWN_KERNEL_FORCE_NONE`, no `MODULE_SIG_FORCE`), so the unsigned NVIDIA
modules keep loading.

## Turning it on

1. **Keys.** `sudo sbctl create-keys` (into `/var/lib/sbctl`, root-only).
   Do this first: switching with the option on but no keys fails at the
   bootloader step (the running generation keeps booting).
2. **Sign.** Set `dots.secureBoot.enable = true;`, then `nh os switch`.
3. **Check.** `sudo sbctl verify`: `EFI/Boot/bootx64.efi`,
   `EFI/systemd/systemd-bootx64.efi` and every `EFI/Linux/nixos-generation-*.efi`
   must show as signed. `EFI/nixos/kernel-*.efi` stays unsigned on purpose: the
   signed generation stubs hash-check the kernel and initrd before booting
   them. Leftovers from plain systemd-boot (`*bzImage.efi`,
   `EFI/systemd/systemd-boot-fallbackx64.efi`) can be deleted.
4. **Setup Mode.** `systemctl reboot --firmware-setup`, then in the firmware's
   Secure Boot menu reset or delete the keys so it enters *Setup Mode* (on ASUS
   boards: Key Management → Clear Secure Boot keys). Keep Secure Boot off for now.
5. **Enroll.** Back in NixOS: `sudo sbctl enroll-keys --microsoft`.
   Keep `--microsoft`: the RTX 3060's option ROM is Microsoft-signed, and
   without those keys the card can show nothing before Linux starts.
6. **Enable.** `systemctl reboot --firmware-setup`, turn Secure Boot on, boot.
   `bootctl status` should say `Secure Boot: enabled (user)`.

## TPM unlock

With Secure Boot on, the TPM can unlock the root disk at boot without the
passphrase. The key is sealed to two PCRs (TPM measurement registers):

- **PCR 7**, the Secure Boot state and keys. If Secure Boot is turned off, the
  keys change, or something signed only by Microsoft boots (a live USB), it
  won't unseal.
- **PCR 15 = 0.** With `tpm2-measure-pcr=yes` the initrd extends PCR 15 as soon
  as it opens a volume. That stops a decoy volume (same UUID, attacker's
  passphrase) from being opened first and then used to unseal the real key.

Because the disk opens by itself, root's password is locked (`users.users.root.hashedPassword = "!"` in the host): a boot that drops to emergency mode refuses to open a shell instead of handing one to whoever is at the keyboard. Recover a machine that won't boot from the installer ISO; `sudo` is unaffected.

The passphrase keyslot stays as the fallback. A firmware update or a change to
the Secure Boot settings changes PCR 7: you get the passphrase prompt, then
re-enroll.

1. **Initrd.** `dots.secureBoot.tpmUnlock` lists the `boot.initrd.luks.devices`
   names (root is already listed in `hosts/nixos/configuration.nix`). It switches
   to the systemd initrd, which is the only one that can talk to the TPM. `nh os switch`,
   reboot, and make sure the passphrase still works. With no TPM keyslot yet,
   it asks for it like before.
2. **Enroll.**
   ```
   sudo systemd-cryptenroll /dev/nvme0n1p3 --tpm2-device=auto \
     --tpm2-pcrs=7+15:sha256=0000000000000000000000000000000000000000000000000000000000000000
   ```
   Add `--tpm2-with-pin=yes` to still type a short PIN at boot; the TPM
   rate-limits guesses.
3. **Reboot.** Root should unlock without a prompt.

Re-enroll after a PCR 7 change:
`sudo systemd-cryptenroll /dev/nvme0n1p3 --wipe-slot=tpm2` followed by step 2's command.
To drop it, wipe the slot and empty the list.

## Backing out

Turn Secure Boot off in the firmware: everything still boots. To drop
lanzaboote too, set the option back to `false` and switch.
