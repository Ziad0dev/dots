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
3. **Check.** `sudo sbctl verify`: the lanzaboote images under `/boot/EFI` must
   show as signed. Leftover unsigned files from the old systemd-boot entries
   (`*bzImage.efi`) are expected and go away as generations rotate.
4. **Setup Mode.** `systemctl reboot --firmware-setup`, then in the firmware's
   Secure Boot menu reset or delete the keys so it enters *Setup Mode* (on ASUS
   boards: Key Management → Clear Secure Boot keys). Keep Secure Boot off for now.
5. **Enroll.** Back in NixOS: `sudo sbctl enroll-keys --microsoft`.
   Keep `--microsoft`: the RTX 3060's option ROM is Microsoft-signed, and
   without those keys the card can show nothing before Linux starts.
6. **Enable.** `systemctl reboot --firmware-setup`, turn Secure Boot on, boot.
   `bootctl status` should say `Secure Boot: enabled (user)`.

## Backing out

Turn Secure Boot off in the firmware: everything still boots. To drop
lanzaboote too, set the option back to `false` and switch.
