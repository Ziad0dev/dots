{ pkgs, ... }:

# Apps, remotes and overrides are declared per user in home/flatpak.nix
# (nix-flatpak). What's left here depends on the running driver.
{
  services.flatpak.enable = true;

  # Flatpak apps need the GL extension matching the loaded NVIDIA driver; its
  # name carries the version, so it is installed at runtime, not declared.
  systemd.user.services.flatpak-nvidia-gl = {
    description = "Install the flatpak GL extension for the loaded NVIDIA driver";
    wantedBy = [ "default.target" ];
    after = [ "flatpak-managed-install.service" ];
    unitConfig = {
      ConditionUser = "!@system";
      ConditionPathExists = "/sys/module/nvidia/version";
    };
    path = [ pkgs.flatpak ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = 30;
    };
    script = ''
      nv=$(tr . - < /sys/module/nvidia/version)
      flatpak install --user -y --noninteractive flathub \
        "org.freedesktop.Platform.GL.nvidia-$nv" \
        "org.freedesktop.Platform.GL32.nvidia-$nv"
    '';
  };
}
