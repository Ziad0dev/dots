{
  lib,
  pkgs,
  ...
}:

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

  poolDisks = map (d: "/mnt/disks/${d}") [
    "pool1"
  ];
in
{
  fileSystems =
    lib.genAttrs poolDisks (path: {
      device = "/dev/disk/by-label/${baseNameOf path}";
      fsType = "ext4";
      options = [
        "nofail"
        "noatime"
        "x-gvfs-hide"
      ];
    })
    // {
      "/mnt/backup" = {
        device = "/dev/disk/by-uuid/6087-5FAB";
        fsType = "exfat";
        noCheck = true;
        options = backupOpts;
      };

      "/mnt/pool" = {
        device = lib.concatStringsSep ":" poolDisks;
        fsType = "mergerfs";
        depends = poolDisks;
        noCheck = true;
        options = [
          "nofail"
          "cache.files=off"
          "category.create=pfrd"
          "func.getattr=newest"
          "dropcacheonclose=false"
          "minfreespace=50G"
          "fsname=pool"
          "x-gvfs-show"
        ];
      };

      "/data/scratch" = {
        device = "/dev/mapper/scratch";
        fsType = "ext4";
        options = [
          "nofail"
          "noatime"
          "x-systemd.requires=systemd-cryptsetup@scratch.service"
        ];
      };
    };

  environment.etc."crypttab".text = ''
    scratch PARTLABEL=scratch /etc/luks-data.key luks,nofail
  '';

  system.fsPackages = [ pkgs.mergerfs ];
  environment.systemPackages = [
    pkgs.exfatprogs
    pkgs.mergerfs
  ];
}
