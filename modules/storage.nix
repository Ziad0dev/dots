{ pkgs, ... }:

let
  baseOpts = [
    "nofail"
    "x-systemd.automount"
    "x-systemd.idle-timeout=600"
    "X-mount.mkdir"
  ];

  backupOpts = baseOpts ++ [
    "uid=0"
    "gid=0"
    "umask=0077"
    "x-gvfs-hide"
  ];
in
{
  # This UUID belongs to the independent exFAT backup drive used by restic.
  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/6087-5FAB";
    fsType = "exfat";
    noCheck = true;
    options = backupOpts;
  };

  # Spare 2 TB ext4 drive (WDC WD2003FZEX, label pool1): general storage.
  # ext4 keeps real ownership, so unlike the exFAT drives it needs no
  # uid/umask options; nofail + automount so a missing drive never blocks boot.
  fileSystems."/mnt/pool1" = {
    device = "/dev/disk/by-uuid/323cb5ac-cf65-4c5a-8276-f7eebe12cda9";
    fsType = "ext4";
    options = [
      "nofail"
      "noatime"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "X-mount.mkdir"
      "x-gvfs-show"
    ];
  };

  environment.systemPackages = [ pkgs.exfatprogs ];
}
