{ pkgs, ... }:

let
  hardening = import ../lib/hardening.nix;

  browserHardening = (removeAttrs hardening [
    "CapabilityBoundingSet"
    "PrivateDevices"
    "RestrictNamespaces"
  ]) // { ProtectSystem = "strict"; };

  wgConfig = "/etc/wireguard/mullvad.conf";
  mullvadDns = "100.64.0.7";

  lanSubnet = "192.168.86.0/24";

  webPort = 8081;
  indexerPort = 9696;
  torrentPort = 51413;
  mediaRoot = "/mnt/media";
in
{
  systemd.services.wg-dns = {
    description = "Pin the Mullvad resolver in the WireGuard config";
    wantedBy = [ "wg.service" ];
    before = [ "wg.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.gnused}/bin/sed -i 's|^DNS = .*|DNS = ${mullvadDns}|' ${wgConfig}";
    };
  };

  vpnNamespaces.wg = {
    enable = true;
    wireguardConfigFile = wgConfig;
    accessibleFrom = [ lanSubnet ];
    portMappings = [
      {
        from = webPort;
        to = webPort;
      }
      {
        from = indexerPort;
        to = indexerPort;
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
      Preferences.WebUI = {
        Address = "*";
        AuthSubnetWhitelistEnabled = true;
        AuthSubnetWhitelist = lanSubnet;
        LocalHostAuth = false;
        Username = "admin";
        Password_PBKDF2 = "@ByteArray(hm8nwYXMLuaC21xtTlnZgA==:CW/ljNjP7EJ09bUSv6OilUpCO6jNZJo+JGKdnZPISC2VfCGdogqSQdotFulINeRZGOsFcXY6B2qUREd3AXf70A==)";
      };
      BitTorrent.Session = {
        DefaultSavePath = "${mediaRoot}/.incoming";
        TempPathEnabled = false;
        DiskIOType = "SimplePreadPwrite";
        UseUPnP = false;
        MaxRatio = 2;
        MaxRatioAction = 1;
        GlobalMaxSeedingMinutes = 1440;
      };
    };
  };

  systemd.services.qbittorrent = {
    vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
    unitConfig.RequiresMountsFor = [ mediaRoot ];
    serviceConfig.MemoryHigh = "2G";
  };

  services.prowlarr = {
    enable = true;
    openFirewall = false;
  };

  systemd.services.prowlarr = {
    vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
    serviceConfig = hardening;
  };

  services.flaresolverr = {
    enable = true;
    openFirewall = false;
  };

  systemd.services.flaresolverr = {
    environment.HOST = "127.0.0.1";
    vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
    serviceConfig = browserHardening // {
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'until ${pkgs.getent}/bin/getent hosts mullvad.net >/dev/null 2>&1; do sleep 2; done'";
    };
  };
}
