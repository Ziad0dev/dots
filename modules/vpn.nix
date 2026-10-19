{
  config,
  lib,
  pkgs,
  username,
  ...
}:

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

  # The Web UI password hash comes from sops, not the (public) config. sops
  # keeps key names in clear text, so the secret is only declared once the key
  # is in the file: sops-nix would fail every secret over a missing one.
  qbtSecret = "qbittorrent-webui-password";
  qbtHasSecret =
    config.dots.secrets.enable
    && lib.hasInfix "\n${qbtSecret}:" ("\n" + builtins.readFile config.dots.secrets.file);
  qbtConf = "${config.services.qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf";
  # runs after the module has installed qBittorrent.conf from the store
  qbtPassword = pkgs.writeShellScript "qbittorrent-webui-password" ''
    conf=${qbtConf}
    tmp=$(${pkgs.coreutils}/bin/mktemp "$conf.XXXXXX")
    LINE="WebUI\\Password_PBKDF2=$(${pkgs.coreutils}/bin/cat ${
      config.sops.secrets.${qbtSecret}.path
    })" \
      ${pkgs.gawk}/bin/awk '{ print } $0 == "[Preferences]" { print ENVIRON["LINE"] }' "$conf" >"$tmp"
    ${pkgs.coreutils}/bin/chmod 600 "$tmp"
    ${pkgs.coreutils}/bin/mv -f "$tmp" "$conf"
  '';

  # The Web UI skips auth for the bridge subnet, and every host process reaches
  # the namespace from the bridge address. Only these users may connect.
  qbtClients = [
    config.services.sonarr.user
    config.services.radarr.user
    username
  ];
  qbtJump = "OUTPUT -d ${config.vpnNamespaces.wg.namespaceAddress} -p tcp --dport ${toString webPort} -j qbt-webui";
  forwardRule = "FORWARD -d ${config.vpnNamespaces.wg.namespaceAddress} -p tcp -m multiport --dports ${toString webPort},${toString indexerPort} ! -i tailscale0 -j DROP";
in
{
  systemd.services.wg-dns = {
    description = "Pin the Mullvad resolver in the WireGuard config";
    wantedBy = [ "wg.service" ];
    unitConfig.ConditionPathExists = wgConfig;
    before = [ "wg.service" ];
    serviceConfig = hardening // {
      Type = "oneshot";
      RemainAfterExit = true;
      PrivateNetwork = true;
      # sed -i writes a temp file next to the target: /etc/wireguard, or the
      # sops secret under /run when the config comes from sops
      ReadWritePaths = [
        "/etc/wireguard"
        "-/run/secrets.d"
      ];
      ExecStart = "${pkgs.gnused}/bin/sed -i --follow-symlinks 's|^DNS = .*|DNS = ${mullvadDns}|' ${wgConfig}";
    };
  };

  systemd.services.wg-resolv-options = {
    description = "Serialise A/AAAA lookups inside the wg namespace";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = wgConfig;
    after = [ "wg.service" ];
    partOf = [ "wg.service" ];
    before = [
      "prowlarr.service"
      "flaresolverr.service"
      "qbittorrent.service"
    ];
    serviceConfig = hardening // {
      Type = "oneshot";
      RemainAfterExit = true;
      PrivateNetwork = true;
      ReadWritePaths = [ "/etc/netns/wg" ];
      ExecStart = "${pkgs.writeShellScript "wg-resolv-options" ''
        ${pkgs.coreutils}/bin/printf '%s\n' \
          "nameserver ${mullvadDns}" \
          "nameserver ${mullvadFallbackDns}" \
          "options single-request-reopen timeout:2 attempts:3" \
          > /etc/netns/wg/resolv.conf
      ''}";
    };
  };

  # The desktop can be installed before its age key and encrypted Mullvad
  # config are restored. Do not run the upstream wg-up script against a
  # missing file (it emits a confusing shell arithmetic error).
  systemd.services.wg.unitConfig.ConditionPathExists = wgConfig;

  systemd.tmpfiles.rules = [
    "d /etc/netns/wg 0755 root root -"
  ];

  vpnNamespaces.wg = {
    enable = true;
    wireguardConfigFile = wgConfig;
    accessibleFrom = [ tailnet ];
    allowedEgress = [ config.vpnNamespaces.wg.bridgeAddress ];
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
    iptables -w -D INPUT -s ${config.vpnNamespaces.wg.namespaceAddress} -d ${config.vpnNamespaces.wg.bridgeAddress} -p tcp --dport 7878 -j ACCEPT 2>/dev/null || true
    iptables -w -I INPUT 1 -s ${config.vpnNamespaces.wg.namespaceAddress} -d ${config.vpnNamespaces.wg.bridgeAddress} -p tcp --dport 7878 -j ACCEPT
    iptables -w -D INPUT -s ${config.vpnNamespaces.wg.namespaceAddress} -d ${config.vpnNamespaces.wg.bridgeAddress} -p tcp --dport 8989 -j ACCEPT 2>/dev/null || true
    iptables -w -I INPUT 1 -s ${config.vpnNamespaces.wg.namespaceAddress} -d ${config.vpnNamespaces.wg.bridgeAddress} -p tcp --dport 8989 -j ACCEPT
    iptables -w -D ${forwardRule} 2>/dev/null || true
    iptables -w -I ${forwardRule}
    iptables -w -N qbt-webui 2>/dev/null || iptables -w -F qbt-webui
    ${lib.concatMapStrings (u: ''
      iptables -w -A qbt-webui -m owner --uid-owner ${u} -j RETURN
    '') qbtClients}
    iptables -w -A qbt-webui -p tcp -j REJECT --reject-with tcp-reset
    iptables -w -D ${qbtJump} 2>/dev/null || true
    iptables -w -I ${qbtJump}
  '';
  networking.firewall.extraStopCommands = ''
    iptables -w -D INPUT -s ${config.vpnNamespaces.wg.namespaceAddress} -d ${config.vpnNamespaces.wg.bridgeAddress} -p tcp --dport 7878 -j ACCEPT 2>/dev/null || true
    iptables -w -D INPUT -s ${config.vpnNamespaces.wg.namespaceAddress} -d ${config.vpnNamespaces.wg.bridgeAddress} -p tcp --dport 8989 -j ACCEPT 2>/dev/null || true
    iptables -w -D ${forwardRule} 2>/dev/null || true
    iptables -w -D ${qbtJump} 2>/dev/null || true
    iptables -w -F qbt-webui 2>/dev/null || true
    iptables -w -X qbt-webui 2>/dev/null || true
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
        # Password_PBKDF2: from sops (qbtPassword above)
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
    unitConfig.ConditionPathExists = wgConfig;
    vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
    unitConfig.RequiresMountsFor = [ mediaRoot ];
    serviceConfig = netnsResolv // {
      MemoryHigh = "2G";
      ExecStartPre = lib.mkIf qbtHasSecret (lib.mkAfter [ "${qbtPassword}" ]);
    };
  };

  sops.secrets.${qbtSecret} = lib.mkIf qbtHasSecret {
    owner = config.services.qbittorrent.user;
    restartUnits = [ "qbittorrent.service" ];
  };

  services.prowlarr = {
    enable = true;
    openFirewall = false;
  };

  systemd.services.prowlarr = {
    unitConfig.ConditionPathExists = wgConfig;
    vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
    serviceConfig =
      hardening
      // netnsResolv
      // {
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
    unitConfig.ConditionPathExists = wgConfig;
    environment.HOST = "127.0.0.1";
    vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
    serviceConfig =
      browserHardening
      // netnsResolv
      // {
        ExecStartPre = "${waitForVpnDns}";
        TimeoutStartSec = 180;
      };
  };
}
