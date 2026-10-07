{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

# Secure Boot with lanzaboote: systemd-boot's signed stub and signed unified
# kernel images, keys in /var/lib/sbctl. Off until the keys exist; turning it
# on before `sbctl create-keys` fails the switch at the bootloader step (the
# current generation keeps booting). Steps: docs/secure-boot.md.
#
# The cachyos kernel sets LOCK_DOWN_KERNEL_FORCE_NONE and no MODULE_SIG_FORCE,
# so the unsigned NVIDIA modules still load with Secure Boot on.
let
  cfg = config.dots.secureBoot;
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  options.dots.secureBoot.enable =
    lib.mkEnableOption "Secure Boot via lanzaboote (needs keys in /var/lib/sbctl first)";

  config = lib.mkMerge [
    # sbctl either way: it creates the keys, enrolls them, and verifies signatures
    { environment.systemPackages = [ pkgs.sbctl ]; }

    (lib.mkIf cfg.enable {
      # lanzaboote replaces the systemd-boot module
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
        configurationLimit = config.boot.loader.systemd-boot.configurationLimit;
      };
    })
  ];
}
