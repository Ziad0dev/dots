{ lib, pkgs, ... }:

let
  remotes = {
    flathub = "https://flathub.org/repo/flathub.flatpakrepo";
    GeForceNOW = "https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow.flatpakrepo";
  };

  packages = [
    "GeForceNOW com.nvidia.geforcenow"
    "flathub com.github.johnfactotum.Foliate"
    "flathub com.github.tchx84.Flatseal"
    "flathub com.usebottles.bottles"
    "flathub io.github.f3d_app.f3d"
    "flathub net.meshlab.MeshLab"
    "flathub org.blender.Blender"
    "flathub org.gnome.SimpleScan"
    "flathub org.kde.kdenlive"
    "flathub org.texstudio.TeXstudio"
  ];

  appIds = map (p: lib.last (lib.splitString " " p)) packages;

  reconcile = pkgs.writeShellScript "flatpak-reconcile" ''
    set -eu
    ${builtins.concatStringsSep "\n" (
      builtins.attrValues (
        builtins.mapAttrs (name: url: "flatpak remote-add --user --if-not-exists ${name} ${url}") remotes
      )
    )}
    ${builtins.concatStringsSep "\n" (
      map (p: "flatpak install --user -y --noninteractive ${p}") packages
    )}
    flatpak override --user --env=SDL_VIDEODRIVER=x11 com.nvidia.geforcenow

    declared="${builtins.concatStringsSep " " appIds}"
    flatpak list --user --app --columns=application | while read -r id; do
      [ -n "$id" ] || continue
      case " $declared " in
        *" $id "*) ;;
        *) flatpak uninstall --user -y --noninteractive "$id" || true ;;
      esac
    done
    flatpak uninstall --user -y --unused --noninteractive || true
  '';
in
{
  services.flatpak.enable = true;

  systemd.user.services.flatpak-managed = {
    description = "Reconcile declared flatpak remotes and packages";
    wantedBy = [ "default.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = reconcile;
      Restart = "on-failure";
      RestartSec = 30;
    };
  };
}
