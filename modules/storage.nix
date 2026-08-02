{ pkgs, ... }:

# modules/storage.nix — declarative mounts for the permanently-attached
# external exFAT drives.
#
# Why these moved off udiskie: udiskie automounts on device-add events at
# session start, which made every drive depend on a chain of things —
# login -> graphical-session.target -> udiskie -> polkit -> device ready.
# The 10 TB drive lost that race repeatedly (large enclosures are slow to
# enumerate, and udiskie doesn't retry). Declarative mounts depend on none
# of it: systemd waits for the device unit and mounts whenever it appears,
# at boot rather than at login.
#
# x-systemd.automount makes each one lazy — the drive isn't touched until
# something reads the path, and idle-timeout unmounts it after 10 minutes
# of no access, so a backup disk isn't held spinning for nothing.
#
# exFAT carries no Unix permissions, so ownership comes from the mount
# options. uid=1001 is ziad0dev; confirm the group with `id -g` if files
# show up owned oddly (100 = users on NixOS).
#
# udiskie stays enabled in home/home.nix for genuinely removable media, but
# must be told to ignore these three by UUID so the two mechanisms can't
# fight over the same device — see the device_config block there.

let
  exfatOpts = [
    "nofail"                      # never block boot if a drive is absent
    "x-systemd.automount"         # mount on first access, not eagerly
    "x-systemd.idle-timeout=600"  # unmount after 10 min idle
    "X-mount.mkdir"               # create the mount point if missing
    "uid=1001"
    "gid=100"
    "umask=0022"
    "x-gvfs-show"                 # show up in Dolphin / file managers
  ];
in
{
  # Music library lives here — see services.mpd in home/home.nix.
  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/6087-5FAB";
    fsType = "exfat";
    options = exfatOpts;
  };

  # NOTE: the 10 TB drive (UUID 2A0B-58D1) is deliberately NOT here.
  # modules/media.nix already declares it at /mnt/media with the media-group
  # ownership Jellyfin needs. One owner per device — declaring it twice would
  # mount the same volume at two paths with conflicting uid/gid options.

  fileSystems."/mnt/newvolume" = {
    device = "/dev/disk/by-uuid/4619-E5D1";
    fsType = "exfat";
    options = exfatOpts;
  };

  # fsck.exfat / exfatlabel. Also what clears the "dirty" flag left by an
  # unclean unmount, which otherwise shows up as a mount that just fails:
  #   sudo fsck.exfat -y /dev/disk/by-uuid/6087-5FAB
  environment.systemPackages = [ pkgs.exfatprogs ];
}
