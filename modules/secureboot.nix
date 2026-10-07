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

  # The keyslot itself is enrolled by hand (systemd-cryptenroll, see the docs);
  # this only makes the initrd try the TPM before asking for the passphrase.
  options.dots.secureBoot.tpmUnlock = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "luks-72749c98-6a12-4a0b-b354-00fd868aa36e" ];
    description = "Names under boot.initrd.luks.devices that the initrd unlocks with the TPM.";
  };

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

    (lib.mkIf (cfg.tpmUnlock != [ ]) {
      # the keyslot is sealed to PCR 7, which only means something with
      # Secure Boot enforcing
      assertions = [
        {
          assertion = cfg.enable;
          message = "dots.secureBoot.tpmUnlock needs dots.secureBoot.enable";
        }
      ];
      # the scripted initrd can't talk to the TPM
      boot.initrd.systemd.enable = true;
      # tpm2-measure-pcr extends PCR 15 once a volume is open, so a key sealed
      # to PCR 15 = 0 can't be unsealed again after a decoy volume was unlocked
      boot.initrd.luks.devices = lib.genAttrs cfg.tpmUnlock (_: {
        crypttabExtraOpts = [
          "tpm2-device=auto"
          "tpm2-measure-pcr=yes"
        ];
      });
    })
  ];
}
