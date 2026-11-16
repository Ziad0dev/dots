# The desktop's system disk, in one place.
#
# Two layouts, picked by `useDisko`:
#
#   false  the current hand-made install: ext4 in LUKS, found by the UUIDs
#          nixos-generate-config wrote. Matches the disk as it is today.
#   true   lib/disko.nix on the same NVMe, addressed by its by-id name:
#          ESP + random-key swap + LUKS2 (`cryptroot`) holding btrfs. Nothing
#          in it changes between installs, so a reinstall needs no edits here.
#
# Reinstalling: set useDisko = true, commit, then boot the dots installer
# and run `dots-install nixos` (docs/install.md). Never flip it on the
# running legacy install: the fstab would point at partitions that don't
# exist yet and the next boot would fail.
#
# The Windows disk (INTEL SSDPEKKF512G8L) is not described here, so disko
# never touches it.
{ lib, inputs, ... }:

let
  useDisko = false;

  # kernel names (nvme0n1/nvme1n1) swap between boots on this board
  disk = "/dev/disk/by-id/nvme-KINGSTON_SKC3000S1024G_50026B7382A52463";

  legacyLuks = "luks-bd950db0-dc83-432a-bec6-0bc1a72bd76e";
in
{
  imports = [
    inputs.disko.nixosModules.disko
    (import ../../lib/disko.nix {
      device = disk;
      swap = "17G";
    })
  ];

  # the layout is always declared, so dots-install can format with it; it
  # only owns fileSystems/swap/initrd once switched on
  disko.enableConfig = useDisko;

  # the initrd tries the TPM keyslot first (modules/secureboot.nix). A fresh
  # LUKS header has no TPM slot until it is re-enrolled; until then the
  # passphrase prompt shows as usual.
  dots.secureBoot.tpmUnlock = [ (if useDisko then "cryptroot" else legacyLuks) ];

  fileSystems = lib.mkIf (!useDisko) {
    "/" = {
      device = "/dev/mapper/${legacyLuks}";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/F9F7-7BCD";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };

  boot.initrd.luks.devices = lib.mkIf (!useDisko) {
    ${legacyLuks}.device = "/dev/disk/by-uuid/bd950db0-dc83-432a-bec6-0bc1a72bd76e";
  };

  # The installer's 17G swap partition, re-keyed randomly every boot. By
  # PARTUUID because the LUKS UUID changes each boot. Sits between zram (100)
  # and the swapfile (-2).
  swapDevices = lib.mkIf (!useDisko) [
    {
      device = "/dev/disk/by-partuuid/58b2a087-4fbb-4521-adb5-91688fb1cc7c";
      randomEncryption.enable = true;
      priority = 10;
    }
  ];
}
