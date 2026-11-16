# One disk: an EFI system partition and a LUKS2 container holding btrfs.
#
#   impermanence = false   subvolumes /  /home  /nix
#   impermanence = true    / is a tmpfs; subvolumes /home  /nix  /persist
#   swap = "17G"           plus a swap partition, re-keyed randomly every boot
#                          (nothing to unlock; rules out hibernation)
#
# Partitions are found by partlabel and the disk by whatever `device` says
# (use /dev/disk/by-id/…), so no UUID ever lands in the config.
#
# The LUKS passphrase is read from /tmp/dots-disk.key while formatting (the
# installer writes it there); afterwards it's typed at boot, or enroll the TPM.
{
  device,
  impermanence ? false,
  swap ? null,
}:
let
  sub = mountpoint: {
    inherit mountpoint;
    mountOptions = [
      "compress=zstd"
      "noatime"
    ];
  };
in
{
  disko.devices = {
    disk.main = {
      type = "disk";
      inherit device;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          ${if swap == null then null else "swap"} = {
            size = swap;
            content = {
              type = "swap";
              randomEncryption = true;
              # between zram (100) and the swapfile (-2)
              priority = 10;
            };
          };
          root = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              passwordFile = "/tmp/dots-disk.key";
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/home" = sub "/home";
                  "/nix" = sub "/nix";
                }
                // (if impermanence then { "/persist" = sub "/persist"; } else { "/root" = sub "/"; });
              };
            };
          };
        };
      };
    };
  }
  // (
    if impermanence then
      {
        nodev."/" = {
          fsType = "tmpfs";
          mountOptions = [
            "size=2G"
            "mode=755"
          ];
        };
      }
    else
      { }
  );
}
