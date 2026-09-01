{ ... }:

let
  hardening = import ../lib/hardening.nix;

  webPort = 8081;
  torrentPort = 51413;
  mediaRoot = "/mnt/media";
in
{
  vpnNamespaces.wg = {
    enable = true;
    wireguardConfigFile = "/etc/wireguard/mullvad.conf";
    accessibleFrom = [ "192.168.86.0/24" ];
    portMappings = [
      {
        from = webPort;
        to = webPort;
      }
      {
        from = 9696;
        to = 9696;
      }
    ];
  };

  users.users.qbittorrent = {
    isSystemUser = true;
    group = "media";
  };

  services.qbittorrent = {
    enable = true;
    user = "qbittorrent";
    group = "media";
    webuiPort = webPort;
    torrentingPort = torrentPort;
    openFirewall = false;
    serverConfig = {
      LegalNotice.Accepted = true;
      Preferences.WebUI.Address = "*";
      BitTorrent.Session = {
        DefaultSavePath = "${mediaRoot}/.incoming";
        TempPathEnabled = true;
        TempPath = "/var/lib/qbittorrent/incomplete";
      };
    };
  };

  systemd.services.qbittorrent = {
    vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
    unitConfig.RequiresMountsFor = [ mediaRoot ];
  };

  systemd.services.prowlarr = {
    vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
    serviceConfig = hardening;
  };

  systemd.services.flaresolverr = {
    environment.HOST = "127.0.0.1";
    vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
  };
}
