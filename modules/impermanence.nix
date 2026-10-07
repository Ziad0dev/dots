{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.dots.impermanence;
in
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  # Root is a tmpfs, so every boot starts from what the config declares;
  # only /nix, /home and the paths below (bind-mounted from /persist) survive.
  # The disk layout has to provide that: lib/disko.nix with impermanence = true.
  options.dots.impermanence = {
    enable = lib.mkEnableOption "root on tmpfs, with declared state kept in /persist";

    directories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra directories to keep across boots.";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/persist".neededForBoot = true;

    environment.persistence."/persist" = {
      hideMounts = true;
      directories = [
        "/var/log"
        "/var/lib/nixos" # uid/gid allocations
        "/var/lib/systemd" # timers, random seed, coredumps
        "/etc/NetworkManager/system-connections"
      ]
      ++ cfg.directories;
      files = [ "/etc/machine-id" ];
    };

    # passwords can't be changed with passwd on a root that resets; they come
    # from the config (hashedPasswordFile, e.g. a sops secret)
    users.mutableUsers = false;

    # sudo's lecture file would otherwise show on every boot
    security.sudo.extraConfig = "Defaults lecture = never";
  };
}
