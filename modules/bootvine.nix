{ inputs, ... }:

# bootvine: replaces the scrolling boot/shutdown log on the console with a live
# tree of pending systemd jobs and a timeline of the slow ones. Starts in the
# (systemd) initrd, so it also shows the LUKS prompt when the TPM unlock falls
# back to the passphrase; hands the console back once SDDM takes its VT.
# Settings: `bootvine defaults --format nix` lists every key for
# services.bootvine.settings.
{
  imports = [ inputs.bootvine.nixosModules.default ];

  services.bootvine.enable = true;
}
