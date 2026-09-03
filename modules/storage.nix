{
  config,
  pkgs,
  username,
  ...
}:

let
  baseOpts = [
    "nofail"
    "x-systemd.automount"
    "x-systemd.idle-timeout=600"
    "X-mount.mkdir"
  ];

  exfatOpts = baseOpts ++ [
    "uid=${toString config.users.users.${username}.uid}"
    "gid=100"
    "umask=0022"
    "x-gvfs-show"
  ];

  backupOpts = baseOpts ++ [
    "uid=0"
    "gid=0"
    "umask=0077"
    "x-gvfs-hide"
  ];
in
{

  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/6087-5FAB";
    fsType = "exfat";
    noCheck = true;
    options = backupOpts;
  };

  fileSystems."/mnt/newvolume" = {
    device = "/dev/disk/by-uuid/4619-E5D1";
    fsType = "exfat";
    noCheck = true;
    options = exfatOpts;
  };

  environment.systemPackages = [ pkgs.exfatprogs ];
}
