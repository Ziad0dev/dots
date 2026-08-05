{ pkgs, ... }:

let
  exfatOpts = [
    "nofail"
    "x-systemd.automount"
    "x-systemd.idle-timeout=600"
    "X-mount.mkdir"
    "uid=1001"
    "gid=100"
    "umask=0022"
    "x-gvfs-show"
  ];
in
{

  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/6087-5FAB";
    fsType = "exfat";
    options = exfatOpts;
  };

  fileSystems."/mnt/newvolume" = {
    device = "/dev/disk/by-uuid/4619-E5D1";
    fsType = "exfat";
    options = exfatOpts;
  };

  environment.systemPackages = [ pkgs.exfatprogs ];
}
