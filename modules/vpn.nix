{ config, pkgs, ... }:

let
  hardening = import ../lib/hardening.nix;
  waitForVpnDns = import ../lib/vpn-ready.nix pkgs;

  browserHardening =
    (removeAttrs hardening [
      "CapabilityBoundingSet"
      "PrivateDevices"
      "RestrictNamespaces"
    ])
    // {
      ProtectSystem = "strict";
    };

  wgConfig = "/etc/wireguard/mullvad.conf";
  mullvadDns = "100.64.0.7";
  mullvadFallbackDns = "10.64.0.1";

  tailnet = "100.64.0.0/10";

  webPort = 8081;
  indexerPort = 9696;
  torrentPort = 51413;
  mediaRoot = "/mnt/media";

  # VPN-Confinement binds the netns resolv.conf onto /etc/resolv.conf, which
  # follows the symlink to resolved's stub-resolv.conf. resolved replaces that
  # file whenever its config changes (tailscale pushing its search domain at
  # boot), which drops the mount and leaves the service on 127.0.0.53. A
  # private /run/systemd/resolve keeps the bind out of resolved's reach.
  netnsResolv = {
    TemporaryFileSystem = [ "/run/systemd/resolve" ];
    BindReadOnlyPaths = [ "/etc/netns/wg/resolv.conf:/run/systemd/resolve/stub-resolv.conf" ];
  };

  forwardRule ="FORWARD -d ${config.vpnNamespaces.wg.namespaceAddress} -p tcp -m multiport --dports ${toString webPort},${toString indexerPort} ! -i tailscale0 -j DROP";
in
{
  systemd.services.wg-dns = {
    description = "Pin the Mullvad resolver in the WireGuard config";
    wantedBy = [ "wg.service" ];
    before = [ "wg.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.gnused}/bin/sed -i --follow-symlinks 's|^DNS = .*|DNS = ${mullvadDns}|' ${wgConfig}";
    };
  };

  systemd.services.wg-resolv-options = {
    description = "Serialise A/AAAA lookups inside the wg namespace";
    wantedBy = [ "multi-user.target" ];
    after = [ "wg.service" ];
    partOf = [ "wg.service" ];
    before = [
      "prowlarr.service"
      "flaresolverr.service"
      "qbittorrent.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.writeShellScript "wg-resolv-options" ''
        ${pkgs.coreutils}/bin/printf '%s\n' \
          "nameserver ${mullvadDns}" \
          "nameserver ${mullvadFallbackDns}" \
          "options single-request-reopen timeout:2 attempts:3" \
          > /etc/netns/wg/resolv.conf
      ''}";
    };
  };

  vpnNamespaces.wg = {
    enable = true;
    wireguardConfigFile = wgConfig;
    accessibleFrom = [ tailnet ];
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

  networking.firewall.extraCommands = ''
    iptables -w -D ${forwardRule} 2>/dev/null || true
    iptables -w -I ${forwardRule}
  '';
  networking.firewall.extraStopCommands = ''
    iptables -w -D ${forwardRule} 2>/dev/null || true
  '';

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
        AuthSubnetWhitelist = "192.168.15.0/24";
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
        MaxRatioAction = 0;
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
    serviceConfig = netnsResolv // {
      MemoryHigh = "2G";
    };
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
    serviceConfig = hardening // netnsResolv // {
      ExecStartPre = "${waitForVpnDns}";
      TimeoutStartSec = 180;
      Restart = "on-failure";
      RestartSec = 10;
    };
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
    serviceConfig = browserHardening // netnsResolv // {
      ExecStartPre = "${waitForVpnDns}";
      TimeoutStartSec = 180;
    };
  };
}
