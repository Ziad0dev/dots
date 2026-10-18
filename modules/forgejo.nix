# Forgejo: self-hosted git forge with Actions, for the LAN only (the tailnet
# gets just the page and Jellyfin).
#
#   LAN      http://nixos.local:3000   (avahi)
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
  lanHost = "nixos.local";
  rootUrl = "http://${lanHost}:${toString httpPort}/";

  forgejoCli = "${lib.getExe cfg.package} --work-path ${cfg.stateDir} --config ${cfg.customDir}/conf/app.ini";
  runnerName = "nixos";
  # 40 hex chars: the runner's token, and the source of its UUID
  runnerSecretFile = "${cfg.stateDir}/actions-runner.secret";
  runnerUuidFile = "${cfg.stateDir}/actions-runner.uuid";
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
        DOMAIN = lanHost;
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

  # every dump gets a new timestamped name and the module never prunes them;
  # keep a week (restic holds the history)
  systemd.tmpfiles.rules = [ "e ${cfg.dump.backupDir} - - - 7d" ];

  # the module doesn't put the CLI on PATH; this runs it as the service user
  # with the service's config: `forgejo-admin admin user list`
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "forgejo-admin" ''
      exec /run/wrappers/bin/sudo -u ${cfg.user} ${forgejoCli} "$@"
    '')
  ];

  networking.firewall.interfaces.${config.dots.lanInterface}.allowedTCPPorts = [
    httpPort
    sshPort
  ];

  # Actions: forgejo-runner 13 no longer registers itself; it needs a UUID and
  # token that Forgejo already knows. Pre-register one from a locally generated
  # secret (idempotent, so it runs on every boot; delete the secret file for a
  # fresh runner).
  systemd.services.forgejo-runner-secret = {
    description = "pre-register the Forgejo Actions runner";
    after = [ "forgejo.service" ];
    requires = [ "forgejo.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = cfg.user;
      Group = cfg.group;
      UMask = "0077";
    };
    script = ''
      if [ ! -s ${runnerSecretFile} ]; then
        od -An -tx1 -N20 /dev/urandom | tr -d ' \n' > ${runnerSecretFile}
      fi
      secret=$(cat ${runnerSecretFile})
      # same derivation as `forgejo-runner create-runner-file`: the UUID is the
      # secret's first 16 characters taken as bytes
      hex=$(printf '%s' "''${secret:0:16}" | od -An -tx1 | tr -d ' \n')
      printf '%s-%s-%s-%s-%s' "''${hex:0:8}" "''${hex:8:4}" "''${hex:12:4}" "''${hex:16:4}" "''${hex:20:12}" > ${runnerUuidFile}

      i=0
      until ${forgejoCli} forgejo-cli actions register --name ${runnerName} --secret-file ${runnerSecretFile}; do
        i=$((i + 1))
        [ $i -ge 30 ] && { echo "forgejo never answered" >&2; exit 1; }
        sleep 2
      done
    '';
  };

  services.forgejo-runner = {
    package = pkgs.forgejo-runner;
    instances.${runnerName} = {
      enable = true;
      secrets.server.connections.default.token_url = runnerSecretFile;
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
        # jobs check out from Forgejo on 127.0.0.1; the qBittorrent Web UI
        # rejects their uid (vpn.nix)
        container.network = "host";
        # ROOT_URL's mDNS name doesn't resolve inside a container
        container.options = "--add-host=${lanHost}:127.0.0.1";
        runner = {
          capacity = 2;
          # container jobs run in Podman (already on); no `native:host` label,
          # so no job runs directly on the host
          labels = [
            "ubuntu-latest:docker://node:22-bookworm"
            "debian-latest:docker://node:22-bookworm"
            "docker:docker://node:22-bookworm"
          ];
        };
        server.connections.default = {
          url = "http://127.0.0.1:${toString httpPort}";
          uuid = "@UUID@";
        };
      };
    };
  };

  # The module has no uuid_url yet, so fill the UUID in at start, the way
  # nixpkgs' own forgejo test does.
  systemd.services."forgejo-runner-${runnerName}" = {
    after = [ "forgejo-runner-secret.service" ];
    requires = [ "forgejo-runner-secret.service" ];
    preStart = ''
      install -m 600 ${config.services.forgejo-runner.instances.${runnerName}.configFile} ./config.yaml
      ${lib.getExe pkgs.replace-secret} "@UUID@" "$CREDENTIALS_DIRECTORY/UUID" ./config.yaml
    '';
    serviceConfig = {
      ExecStart = lib.mkForce "${lib.getExe config.services.forgejo-runner.package} daemon --config ./config.yaml";
      LoadCredential = [ "UUID:${runnerUuidFile}" ];
    };
  };
}
