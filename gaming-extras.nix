{ config, lib, pkgs, ... }:

# Complements your existing gaming.nix — does NOT replace it.
# gaming.nix keeps owning the kernel, Steam, gamescope, gamemode, ananicy.

{
  environment.systemPackages = with pkgs; [
    protontricks # per-game proton prefix surgery (winetricks for a specific appid)
    winetricks
    lutris       # battle.net, emulators, standalone wine (heroic lives in gaming.nix)
    # vkbasalt   # post-processing (CAS sharpen etc); per game: ENABLE_VKBASALT=1 %command%
  ];

  # MangoHud lives HM-side (gaming-home.nix) so its config is declarative.

  # Controllers — uncomment what you actually own. Both build out-of-tree
  # kernel modules against the CachyOS kernel, so only carry what you use:
  # hardware.xone.enable = true;    # Xbox wireless dongle (unfree firmware)
  # hardware.xpadneo.enable = true; # Xbox pads over Bluetooth

  # LAN game streaming to Moonlight clients:
  # services.sunshine = { enable = true; capSysAdmin = true; openFirewall = true; };

  # Fallback-kernel specialisation — correction to what I suggested earlier:
  # each specialisation copies its OWN kernel+initrd into the ESP for every
  # generation. Your ESP is 200 MiB and already overflowed once; with
  # configurationLimit = 3 this can refill it. Rolling back a generation
  # already boots that generation's kernel, which covers the "chaotic kernel
  # broke NVIDIA" case. Only enable this if you also drop configurationLimit
  # to 2 and accept the ESP pressure:
  # specialisation.stock-kernel.configuration = {
  #   boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
  # };
}
