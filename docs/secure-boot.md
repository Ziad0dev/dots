# Secure Boot

`modules/secureboot.nix` adds [lanzaboote](https://github.com/nix-community/lanzaboote)
(pinned to a release tag in `flake.nix`): systemd-boot's signed stub and signed
unified kernel images, with your own keys in `/var/lib/sbctl`. The desktop host
configuration enables lanzaboote; Secure Boot still needs its keys enrolled in
firmware and enabled in the firmware menu. `sbctl` is installed either way.

The disks are already LUKS-encrypted; Secure Boot adds that only boot files you
signed will run, so nobody can swap the kernel or initrd on the unencrypted
`/boot` to capture the passphrase.

The cachyos kernel doesn't force lockdown under Secure Boot
(`LOCK_DOWN_KERNEL_FORCE_NONE`, no `MODULE_SIG_FORCE`), so the unsigned NVIDIA
modules keep loading.

## Turning it on

1. **Keys.** If keys are not already present, run `sudo sbctl create-keys`
   (into `/var/lib/sbctl`, root-only). Switching with the option on but no keys
   fails at the bootloader step (the running generation keeps booting).
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

1. **Confirm the root device.** On this host, the root container UUID is
   `bd950db0-dc83-432a-bec6-0bc1a72bd76e` (currently `/dev/nvme1n1p2`; NVMe
   device numbering can vary). The
   separate encrypted swap container is `f04ed75f-34bc-4c92-b7db-379feff63a71`
   (currently `/dev/nvme1n1p3`). Confirm these with `lsblk -f` before running
   enrollment commands; use the stable UUID path below, not a guessed partition
   number.
2. **Initrd.** `dots.secureBoot.tpmUnlock` lists the
   `boot.initrd.luks.devices` names. For this root, set it to
   `[ "luks-bd950db0-dc83-432a-bec6-0bc1a72bd76e" ]` in
   `hosts/nixos/configuration.nix`. Keep `dots.secureBoot.enable = true;` as
   well, since the module requires Secure Boot for TPM unlock. Switch the
   configuration and reboot; with no TPM keyslot yet, it should still ask for
   the existing passphrase.
3. **Enroll.** After Secure Boot is enabled in firmware, enroll the TPM key on
   the root container (not the encrypted swap container):
   ```
   sudo systemd-cryptenroll /dev/disk/by-uuid/bd950db0-dc83-432a-bec6-0bc1a72bd76e --tpm2-device=auto \
     --tpm2-pcrs=7+15:sha256=0000000000000000000000000000000000000000000000000000000000000000
   ```
   Add `--tpm2-with-pin=yes` to still type a short PIN at boot; the TPM
   rate-limits guesses.
4. **Reboot.** Root should unlock without a prompt. The encrypted swap mapping
   partition is currently left untouched but is not configured as swap. The
   host uses zram and a swapfile instead, so boot does not wait for that volume.

Re-enroll after a PCR 7 change:
`sudo systemd-cryptenroll /dev/disk/by-uuid/bd950db0-dc83-432a-bec6-0bc1a72bd76e --wipe-slot=tpm2`
followed by step 3's enrollment command. Verify the target UUID with `lsblk -f`
before wiping or enrolling any slot.
To drop it, wipe the slot and empty the list.

## Backing out

Turn Secure Boot off in the firmware: everything still boots. To drop
lanzaboote too, set the option back to `false` and switch.
