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

  environment.systemPackages = [ pkgs.exfatprogs ];
}
