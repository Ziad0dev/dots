# Secure Boot

`modules/secureboot.nix` adds [lanzaboote](https://github.com/nix-community/lanzaboote)
(pinned to a release tag in `flake.nix`): systemd-boot's signed stub and signed
unified kernel images, with your own keys in `/var/lib/sbctl`. The desktop host
configuration enables lanzaboote; Secure Boot still needs its keys enrolled in
firmware and enabled in the firmware menu. `sbctl` is installed either way.
On an impermanent host, `/var/lib/sbctl` is persisted under `/persist`, and the
installer restores the keys there.

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

1. **Find the root container.** `hosts/nixos/disk.nix` names it:
   today's install is `/dev/disk/by-uuid/bd950db0-dc83-432a-bec6-0bc1a72bd76e`;
   after a `dots-install` reinstall (`useDisko = true`) it is
   `/dev/disk/by-partlabel/disk-main-root`. Use those stable paths: the kernel
   names (`nvme0n1`/`nvme1n1`) swap between boots on this board, and the
   other NVMe holds Windows. The swap partition next to it is re-keyed
   randomly every boot and has nothing to enroll.
2. **Initrd.** `dots.secureBoot.tpmUnlock` (set in `hosts/nixos/disk.nix`,
   per layout) lists the `boot.initrd.luks.devices` names the initrd tries
   the TPM for. It needs `dots.secureBoot.enable = true;`. With no TPM keyslot
   yet, boot still asks for the passphrase.
3. **Enroll.** After Secure Boot is enabled in firmware, enroll the TPM key on
   the root container (`$root` = the path from step 1):
   ```
   sudo systemd-cryptenroll "$root" --tpm2-device=auto \
     --tpm2-pcrs=7+15:sha256=0000000000000000000000000000000000000000000000000000000000000000
   ```
   Add `--tpm2-with-pin=yes` to still type a short PIN at boot; the TPM
   rate-limits guesses.
4. **Reboot.** Root should unlock without a prompt.

Re-enroll after a PCR 7 change, or after a reinstall (a new LUKS header has
no TPM slot): `sudo systemd-cryptenroll "$root" --wipe-slot=tpm2`, then
step 3. Check the path with `lsblk -f` before wiping or enrolling any slot.
To drop it, wipe the slot and empty the list.

## Backing out

Turn Secure Boot off in the firmware: everything still boots. To drop
lanzaboote too, set the option back to `false` and switch.
