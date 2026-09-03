{ pkgs, ... }:

let
  remotes = {
    flathub = "https://flathub.org/repo/flathub.flatpakrepo";
    GeForceNOW = "https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow.flatpakrepo";
  };

  packages = [
    "GeForceNOW com.nvidia.geforcenow"
  ];
in
{
  services.flatpak.enable = true;

  systemd.services.flatpak-managed = {
    description = "Reconcile declared flatpak remotes and packages";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "flatpak-system-helper.service"
    ];
    wants = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      ${builtins.concatStringsSep "\n" (
        builtins.attrValues (
          builtins.mapAttrs (name: url: "flatpak remote-add --if-not-exists ${name} ${url}") remotes
        )
      )}
      ${builtins.concatStringsSep "\n" (map (p: "flatpak install -y --noninteractive ${p}") packages)}
    '';
  };
}
