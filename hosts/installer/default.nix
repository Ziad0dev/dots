# Installer ISO: the stock minimal one, plus `dots-install <host>` and every
# host listed in dots.installer.hosts prebuilt into the image, so an install
# needs no network and builds nothing.
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
  inherit (config.dots.installer) hosts;

  # host name -> the store paths dots-install needs
  hostCase = lib.concatStrings (
    lib.mapAttrsToList (
      name: sys:
      let
        sc = sys.config;
      in
      ''
        ${name})
            toplevel=${sc.system.build.toplevel}
            disko=${sc.system.build.destroyFormatMount}
            keyfile=${lib.optionalString sc.dots.secrets.enable sc.dots.secrets.keyFile}
            ;;
      ''
    ) hosts
  );

  dotsInstall = pkgs.writeShellApplication {
    name = "dots-install";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      die() { printf 'dots-install: %s\n' "$1" >&2; exit 1; }
      usage="usage: dots-install <${lib.concatStringsSep "|" (lib.attrNames hosts)}> [--age-key FILE]"

      [ "$(id -u)" = 0 ] || exec sudo "$0" "$@"

      host="''${1:-}"
      [ -n "$host" ] || die "$usage"
      shift
      agekey=""
      while [ $# -gt 0 ]; do
          case "$1" in
              --age-key) agekey="''${2:-}"; shift 2 ;;
              *) die "$usage" ;;
          esac
      done

      case "$host" in
      ${hostCase}
          *) die "unknown host '$host'; $usage" ;;
      esac

      if [ -n "$keyfile" ]; then
          [ -r "$agekey" ] || die "$host decrypts its secrets with an age key: pass --age-key FILE"
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

      echo ">> partitioning (everything on the target disk is erased)"
      "$disko"/bin/disko-destroy-format-mount --yes-wipe-all-disks

      if [ -n "$keyfile" ]; then
          echo ">> age key -> $keyfile"
          install -D -m 0400 "$agekey" "/mnt$keyfile"
      fi

      echo ">> installing $toplevel"
      nixos-install --system "$toplevel" --no-root-passwd --no-channel-copy

      echo ">> done: reboot into $host"
    '';
  };
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  options.dots.installer.hosts = lib.mkOption {
    type = lib.types.attrsOf lib.types.raw;
    default = { };
    description = "nixosSystems (with a disko layout) that dots-install can put on a disk.";
  };

  config = {
    isoImage.storeContents = lib.concatMap (sys: [
      sys.config.system.build.toplevel
      sys.config.system.build.destroyFormatMount
    ]) (lib.attrValues hosts);

    # the flake source, to read or clone from (hosts/vm/test-age-key.txt is here)
    environment.etc.dots.source = inputs.self;

    environment.systemPackages = [
      dotsInstall
      pkgs.git
      pkgs.age
      pkgs.sops
    ];

    # headless installs: the serial console gets the autologin shell too
    boot.kernelParams = [ "console=ttyS0,115200" ];

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # build speed over a smaller image
    isoImage.squashfsCompression = "zstd -Xcompression-level 6";
  };
}
