# Forgejo: self-hosted git forge with Actions, for the tailnet and the LAN.
#
#   tailnet  https://nixos.taile88a1e.ts.net:10000   (tailscale serve; 443 is
#            the page and 8443 Jellyfin, 10000 is the last port serve allows)
#   LAN      http://<lan ip>:3000
#   git+ssh  ssh://forgejo@<host>:2222/<owner>/<repo>.git  (built-in server)
#
# First admin (forgejo-admin wraps the CLI, see below):
#   forgejo-admin admin user create --admin --username <name> --email <mail> --random-password
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.forgejo;
  httpPort = 3000;
  sshPort = 2222;
  servePort = 10000;
  tailnetHost = "nixos.taile88a1e.ts.net";
  rootUrl = "https://${tailnetHost}:${toString servePort}/";

  forgejoCli = "${lib.getExe cfg.package} --work-path ${cfg.stateDir} --config ${cfg.customDir}/conf/app.ini";
  runnerTokenFile = "${cfg.stateDir}/actions-runner.env";
in
{
  services.forgejo = {
    enable = true;
    package = pkgs.forgejo;
    database.type = "sqlite3";
    lfs.enable = true;

    # daily `forgejo dump` (repos + db + config) for restic to pick up
    dump = {
      enable = true;
      type = "tar.zst";
      interval = "03:40";
    };

    settings = {
      DEFAULT.APP_NAME = "forge";

      server = {
        DOMAIN = tailnetHost;
        ROOT_URL = rootUrl;
        HTTP_ADDR = "0.0.0.0";
        HTTP_PORT = httpPort;
        # built-in SSH server: no changes to the host's sshd
        START_SSH_SERVER = true;
        BUILTIN_SSH_SERVER_USER = "forgejo";
        SSH_LISTEN_HOST = "0.0.0.0";
        SSH_PORT = sshPort;
        SSH_LISTEN_PORT = sshPort;
        LANDING_PAGE = "explore";
      };

      service = {
        # only accounts the admin creates; nothing reachable from outside anyway
        DISABLE_REGISTRATION = true;
        REQUIRE_SIGNIN_VIEW = false;
      };

      session.COOKIE_SECURE = false; # the LAN side is plain http

      repository = {
        DEFAULT_BRANCH = "main";
        ENABLE_PUSH_CREATE_USER = true;
      };

      # GitHub pull mirrors (refresh every 8h unless set per repo)
      mirror = {
        ENABLED = true;
        DEFAULT_INTERVAL = "8h";
        MIN_INTERVAL = "10m";
      };
      migrations.ALLOWED_DOMAINS = "github.com,*.github.com,codeberg.org,gitlab.com";

      actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "https://code.forgejo.org";
      };

      log.LEVEL = "Warn";
    };
  };

  # Publish to the tailnet over HTTPS, like hello-page and Jellyfin.
  systemd.services.forgejo-serve = {
    description = "publish Forgejo to the tailnet";
    wantedBy = [ "multi-user.target" ];
    after = [
      "tailscaled.service"
      "forgejo.service"
    ];
    wants = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "forgejo-serve" ''
        i=0
        while [ $i -lt 60 ]; do
          if ${pkgs.tailscale}/bin/tailscale status --json >/dev/null 2>&1; then
            exec ${pkgs.tailscale}/bin/tailscale serve --bg --https ${toString servePort} http://127.0.0.1:${toString httpPort}
          fi
          ${pkgs.coreutils}/bin/sleep 2
          i=$((i + 1))
        done
        echo "tailscaled never became ready" >&2
        exit 1
      '';
    };
  };

  # the module doesn't put the CLI on PATH; this runs it as the service user
  # with the service's config: `forgejo-admin admin user list`
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "forgejo-admin" ''
      exec /run/wrappers/bin/sudo -u ${cfg.user} ${forgejoCli} "$@"
    '')
  ];

  # tailscale0 is already a trusted interface (hello-page.nix)
  networking.firewall.interfaces.${config.dots.lanInterface}.allowedTCPPorts = [
    httpPort
    sshPort
  ];

  # Actions: the runner registers with a token Forgejo mints for itself, once
  # (the file is kept; delete it to re-register).
  systemd.services.forgejo-runner-token = {
    description = "mint the Forgejo Actions runner registration token";
    after = [ "forgejo.service" ];
    requires = [ "forgejo.service" ];
    unitConfig.ConditionPathExists = "!${runnerTokenFile}";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = cfg.user;
      Group = cfg.group;
      UMask = "0077";
    };
    script = ''
      i=0
      until token=$(${forgejoCli} actions generate-runner-token 2>/dev/null) && [ -n "$token" ]; do
        i=$((i + 1))
        [ $i -ge 30 ] && { echo "forgejo never answered" >&2; exit 1; }
        sleep 2
      done
      printf 'TOKEN=%s\n' "$token" > ${runnerTokenFile}
    '';
  };

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.nixos = {
      enable = true;
      name = config.networking.hostName;
      url = "http://127.0.0.1:${toString httpPort}";
      tokenFile = runnerTokenFile;
      # container jobs run in Podman (already on); `native` runs on the host
      labels = [
        "ubuntu-latest:docker://node:22-bookworm"
        "debian-latest:docker://node:22-bookworm"
        "docker:docker://node:22-bookworm"
        "native:host"
      ];
      hostPackages = with pkgs; [
        bash
        coreutils
        curl
        gawk
        git
        gnused
        nodejs
        wget
        nix
      ];
      settings = {
        container.network = "host";
        runner.capacity = 2;
      };
    };
  };

  systemd.services.gitea-runner-nixos = {
    after = [ "forgejo-runner-token.service" ];
    requires = [ "forgejo-runner-token.service" ];
  };
}
