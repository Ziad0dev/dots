# Installer ISO: the stock minimal one, plus `dots-install <host>`.
#
#   dots.installer.hosts        prebuilt into the image: the install needs no
#                               network and builds nothing (the vm host)
#   dots.installer.onlineHosts  only the disk layout is in the image; the
#                               system is built from the flake into the
#                               target's store, from the binary caches the
#                               host itself uses (the desktop: its closure is
#                               tens of GB)
#
#   nix build .#nixosConfigurations.installer.config.system.build.isoImage
{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}:

let
  cfg = config.dots.installer;
  inherit (cfg) hosts onlineHosts;
  allHosts = hosts // onlineHosts;

  flakeRef = "path:${inputs.self}";

  # host name -> what dots-install needs to know about it
  hostCase = lib.concatStrings (
    lib.mapAttrsToList (
      name: sys:
      let
        sc = sys.config;
        online = onlineHosts ? ${name};
        impermanent = lib.attrByPath [ "dots" "impermanence" "enable" ] false sc;
        keyfile =
          if lib.attrByPath [ "dots" "secrets" "enable" ] false sc then
            "${lib.optionalString impermanent "/persist"}${
              lib.attrByPath [ "dots" "secrets" "keyFile" ] "/var/lib/sops-nix/key.txt" sc
            }"
          else
            "";
        secureboot = lib.attrByPath [ "dots" "secureBoot" "enable" ] false sc;
        pki = "${lib.optionalString impermanent "/persist"}${
          lib.attrByPath [ "boot" "lanzaboote" "pkiBundle" ] "/var/lib/sbctl" sc
        }";
        user = sys._module.specialArgs.username or "";
        u = sc.users.users.${user} or null;
        disks = lib.mapAttrsToList (_: d: d.device) sc.disko.devices.disk;
      in
      ''
        ${name})
            ${if online then "toplevel=" else "toplevel=${sc.system.build.toplevel}"}
            disko=${sc.system.build.destroyFormatMount}
            diskoOn=${lib.boolToString sc.disko.enableConfig}
            keyfile=${keyfile}
            secureboot=${lib.boolToString secureboot}
            pki=${pki}
            user=${user}
            owner=${
              if u != null && u.uid != null then
                "${toString u.uid}:${toString sc.users.groups.${u.group}.gid}"
              else
                ""
            }
            disks=(${lib.escapeShellArgs disks})
            ;;
      ''
    ) allHosts
  );

  dotsInstall = pkgs.writeShellApplication {
    name = "dots-install";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.util-linux
      pkgs.git
    ];
    text = ''
      die() { printf 'dots-install: %s\n' "$1" >&2; exit 1; }
      usage="usage: dots-install <${lib.concatStringsSep "|" (lib.attrNames allHosts)}> [--age-key FILE] [--sbctl DIR] [--no-clone]"

      [ "$(id -u)" = 0 ] || exec sudo "$0" "$@"

      host="''${1:-}"
      [ -n "$host" ] || die "$usage"
      shift
      agekey=""
      sbctl=""
      clone=1
      while [ $# -gt 0 ]; do
          case "$1" in
              --age-key) agekey="''${2:-}"; shift 2 ;;
              --sbctl) sbctl="''${2:-}"; shift 2 ;;
              --no-clone) clone=0; shift ;;
              *) die "$usage" ;;
          esac
      done

      case "$host" in
      ${hostCase}
          *) die "unknown host '$host'; $usage" ;;
      esac

      # a layout that is declared but not switched on would install a system
      # whose fstab still names the old partitions
      [ "$diskoOn" = true ] || die "$host has disko.enableConfig off (hosts/$host/disk.nix: useDisko = true, commit, rebuild the ISO)"

      if [ -n "$keyfile" ]; then
          [ -r "$agekey" ] || die "$host decrypts its secrets with an age key: pass --age-key FILE"
      fi
      # lanzaboote signs the boot files during the install: without the keys
      # the bootloader step fails. Restore them (restic: /var/lib/sbctl), as
      # the firmware already trusts those.
      if [ "$secureboot" = true ]; then
          [ -r "$sbctl/keys/db/db.key" ] || die "$host boots with Secure Boot: pass --sbctl DIR (a copy of its /var/lib/sbctl), or turn dots.secureBoot.enable off for the first install"
      fi

      for d in "''${disks[@]}"; do
          [ -b "$d" ] || die "target disk $d is not here (lsblk; ls -l /dev/disk/by-id)"
          # NTFS, BitLocker or a Microsoft reserved partition: a Windows disk,
          # which no dots layout targets. The desktop has one next to it.
          if lsblk -nro FSTYPE,PARTTYPE "$d" |
              grep -qiE '(^|[[:space:]])(ntfs|bitlocker)([[:space:]]|$)|e3c9e316-0b5c-4db8-817d-f92df00215ae'; then
              [ "''${DOTS_ALLOW_WINDOWS:-}" = 1 ] ||
                  die "$d holds Windows partitions; refusing to wipe it (check hosts/$host/disk.nix; DOTS_ALLOW_WINDOWS=1 overrides)"
          fi
      done

      echo ">> about to ERASE:"
      lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL "''${disks[@]}"
      if [ "''${DOTS_YES:-}" != 1 ]; then
          read -rp "type 'yes' to wipe these disks: " ok
          [ "$ok" = yes ] || die "aborted"
      fi

      # the LUKS passphrase, read by the disko layout while formatting. The
      # umask stays local: disko and nixos-install create /nix, /home and
      # /persist, which must not end up 0700.
      if [ -n "''${DOTS_DISK_PASSWORD:-}" ]; then
          p1="$DOTS_DISK_PASSWORD"
      else
          read -rsp "disk passphrase: " p1; echo
          read -rsp "again: " p2; echo
          [ -n "$p1" ] && [ "$p1" = "$p2" ] || die "passphrases empty or different"
      fi
      (umask 077; printf '%s' "$p1" >/tmp/dots-disk.key)
      trap 'rm -f /tmp/dots-disk.key' EXIT

      echo ">> partitioning"
      "$disko"/bin/disko-destroy-format-mount --yes-wipe-all-disks

      if [ -n "$keyfile" ]; then
          echo ">> age key -> $keyfile"
          install -D -m 0400 "$agekey" "/mnt$keyfile"
      fi
      if [ "$secureboot" = true ]; then
          echo ">> Secure Boot keys -> $pki"
          mkdir -p "/mnt$pki"
          cp -a "$sbctl"/. "/mnt$pki"/
          chmod -R go-rwx "/mnt$pki"
      fi

      if [ -n "$toplevel" ]; then
          echo ">> installing $toplevel"
          nixos-install --system "$toplevel" --no-root-passwd --no-channel-copy
      else
          echo ">> building and installing ${flakeRef}#$host (into /mnt's store)"
          nixos-install --flake "${flakeRef}#$host" --no-root-passwd --no-channel-copy
      fi

      # Keep a checkout for nh and future updates, but never pair the installed
      # generation with a different revision of the dots source.
      if [ "$clone" = 1 ] && [ -n "$user" ] && [ -n "$owner" ]; then
          home="/mnt/home/$user"
          dots="$home/dots"
          if [ ! -e "$dots" ]; then
              echo ">> checkout -> ~$user/dots"
              mkdir -p "$home"
              use_embedded_source() {
                  rm -rf "$dots"
                  mkdir -p "$dots"
                  cp -a /etc/dots/. "$dots"/
                  chmod -R u+w "$dots"
                  git -C "$dots" init --quiet -b main
                  git -C "$dots" remote add origin ${lib.escapeShellArg cfg.repoUrl}
                  echo "   (used the ISO's exact source; 'git fetch' and reset once online)"
              }
              if [ -n ${lib.escapeShellArg (inputs.self.rev or "")} ] &&
                  git clone --quiet ${lib.escapeShellArg cfg.repoUrl} "$dots" 2>/dev/null; then
                  if ! git -C "$dots" checkout --quiet ${
                    lib.escapeShellArg (inputs.self.rev or "")
                  } 2>/dev/null; then
                      use_embedded_source
                  fi
              else
                  use_embedded_source
              fi
              chown -R "$owner" "$home"
              chmod 0700 "$home"
          fi
      fi

      cat <<EOF
      >> done: reboot into $host
         afterwards, if it applies:
           - TPM unlock:  re-enroll the keyslot, docs/secure-boot.md
           - Tailscale:   sudo tailscale up
      EOF
    '';
  };
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  options.dots.installer = {
    hosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = { };
      description = "nixosSystems (with a disko layout) prebuilt into the image for offline installs.";
    };

    onlineHosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = { };
      description = "nixosSystems (with a disko layout) built from the flake at install time.";
    };

    repoUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/Ziad0dev/dots";
      description = "Cloned to ~/dots on the installed system.";
    };
  };

  config = {
    isoImage.storeContents =
      lib.concatMap (sys: [
        sys.config.system.build.toplevel
        sys.config.system.build.destroyFormatMount
      ]) (lib.attrValues hosts)
      ++ map (sys: sys.config.system.build.destroyFormatMount) (lib.attrValues onlineHosts);

    # the flake source, to read or clone from
    environment.etc.dots.source = inputs.self;

    environment.systemPackages = [
      dotsInstall
      pkgs.git
      pkgs.age
      pkgs.sops
      # restoring the age key / Secure Boot keys from the backup drive
      pkgs.restic
      pkgs.exfatprogs
      # hardware report for a new host (hardware.facter.reportPath)
      pkgs.nixos-facter
    ];

    # headless installs: the serial console gets the autologin shell too
    boot.kernelParams = [ "console=ttyS0,115200" ];

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # online installs fetch from the caches the target uses (chaotic's
      # kernel and NVIDIA driver, Hyprland, …) instead of compiling them
      extra-substituters = lib.unique (
        lib.concatMap (
          sys:
          (sys.config.nix.settings.substituters or [ ]) ++ (sys.config.nix.settings.extra-substituters or [ ])
        ) (lib.attrValues onlineHosts)
      );
      extra-trusted-public-keys = lib.unique (
        lib.concatMap (
          sys:
          (sys.config.nix.settings.trusted-public-keys or [ ])
          ++ (sys.config.nix.settings.extra-trusted-public-keys or [ ])
        ) (lib.attrValues onlineHosts)
      );
    };

    # build speed over a smaller image
    isoImage.squashfsCompression = "zstd -Xcompression-level 6";
  };
}
