# Offline knowledge, maps and AI: everything here keeps working with no
# internet. Kiwix serves the library (Wikipedia, medicine, survival guides,
# repair manuals, books), a MapLibre page shows the Protomaps planet, Open
# WebUI talks to the local models and can search the library, and a weekly
# archive keeps this system rebuildable offline. One hub page links it all.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.zi.offline;
  catalog = import ./catalog.nix;
  offline = import ./packages.nix { inherit pkgs; };
  inherit (lib)
    mkOption
    mkIf
    mkMerge
    types
    optional
    optionals
    ;

  library = "${cfg.kiwix.dir}/library.xml";
  stateDir = "/var/lib/offline-sync";

  # one entry per book; a book in several sets stays in the first set's dir
  books = lib.attrValues (
    lib.foldl' (acc: item: if acc ? ${item.book} then acc else acc // { ${item.book} = item; }) { } (
      lib.concatMap (
        set:
        map (book: {
          inherit book;
          dir = cfg.kiwix.setDirs.${set} or cfg.kiwix.dir;
        }) catalog.kiwix.${set}.books
      ) cfg.kiwix.sets
      ++ map (book: {
        inherit book;
        inherit (cfg.kiwix) dir;
      }) cfg.kiwix.extraBooks
    )
  );

  kiwixDirs = lib.unique ([ cfg.kiwix.dir ] ++ map (b: b.dir) books);
  dataDirs = lib.unique (
    optionals cfg.kiwix.enable kiwixDirs
    ++ optional cfg.maps.enable cfg.maps.dir
    ++ optional cfg.docs.enable cfg.docs.dir
    ++ optional cfg.apps.enable cfg.apps.dir
    ++ optional cfg.navigation.enable cfg.navigation.dir
  );
  archiveDirs = lib.unique (
    optional (cfg.archive.cacheDir != null) cfg.archive.cacheDir
    ++ optional (cfg.archive.bundle != null) (dirOf cfg.archive.bundle)
    ++ lib.attrValues cfg.archive.models
  );

  syncConfig = pkgs.writeText "offline-sync.json" (
    builtins.toJSON {
      inherit stateDir;
      inherit (cfg.sync) downloadLimit;
      kiwix = {
        inherit (cfg.kiwix) enable;
        inherit library books;
        inherit (cfg.kiwix) shelf;
      };
      maps = {
        inherit (cfg.maps) enable dir refreshDays;
      };
      docs = {
        inherit (cfg.docs) enable dir;
        files = catalog.docs // cfg.docs.extra;
      };
      apps = {
        inherit (cfg.apps)
          enable
          dir
          abi
          fdroid
          direct
          ;
      };
      navigation = {
        inherit (cfg.navigation)
          enable
          dir
          regions
          languages
          ;
        listen = "tcp://127.0.0.1:${toString cfg.navigation.routingPort}";
      };
      archive = {
        inherit (cfg.archive) cacheDir flake bundle;
        # created by the user before root copies the models into them
        modelDirs = lib.attrValues cfg.archive.models;
      };
    }
  );

  hubConfig = pkgs.writeTextDir "config.json" (
    builtins.toJSON {
      host = config.networking.hostName;
      library = cfg.kiwix.enable;
      maps = cfg.maps.enable;
      docs = cfg.docs.enable;
      apps = cfg.apps.enable;
      navigation = cfg.navigation.enable;
      aiPort = if cfg.ai.enable then cfg.ai.port else null;
      meshtasticPort = if cfg.meshtastic.enable then cfg.meshtastic.port else null;
      nixCache = cfg.archive.cacheDir;
      inherit (cfg.archive) flake bundle;
    }
  );

  sandbox = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectSystem = "strict";
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    SystemCallArchitectures = "native";
    UMask = "0022";
    Nice = 19;
    IOSchedulingClass = "idle";
  };

  # The download and archive jobs write to directories that may not exist
  # yet, and systemd builds a unit's mount namespace before any of its
  # commands run: a missing ReadWritePaths entry fails the whole unit. They
  # run as the user, so "full" (read-only /usr, /boot, /etc) plus the user's
  # own permissions bound them, and they create their directories themselves.
  userJob = sandbox // {
    ProtectSystem = "full";
  };

  # what the user may start and stop without sudo
  units = [
    "offline-sync.service"
    "offline-archive.service"
    "kiwix-serve.service"
  ]
  ++ optionals cfg.ai.enable [
    "open-webui.service"
    "offline-library-tools.service"
  ]
  # the sync restarts these once it has rebuilt their data
  ++ optionals cfg.navigation.enable [
    "offline-routing.service"
    "offline-search.service"
  ];

  setList = lib.concatStringsSep ", " (
    lib.mapAttrsToList (name: set: "`${name}` (${set.size})") catalog.kiwix
  );
in
{
  options.zi.offline = {
    enable = lib.mkEnableOption "offline knowledge, maps and AI for when the internet is gone";

    user = mkOption {
      type = types.str;
      description = "Owner of the downloaded data; the download and archive jobs run as this user.";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Group of the downloaded data.";
    };

    sync = {
      onCalendar = mkOption {
        type = types.str;
        default = "monthly";
        description = "When to look for new releases of the library and the map (systemd OnCalendar).";
      };
      downloadLimit = mkOption {
        type = types.str;
        default = "0";
        example = "20M";
        description = "Overall download speed cap in bytes per second (aria2 syntax); 0 means none.";
      };
    };

    kiwix = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Download and serve the Kiwix library.";
      };
      dir = mkOption {
        type = types.str;
        example = "/srv/offline/kiwix";
        description = "Where ZIM files and library.xml are kept.";
      };
      sets = mkOption {
        type = types.listOf (types.enum (lib.attrNames catalog.kiwix));
        default = [
          "survival"
          "medical"
          "encyclopedia"
          "practical"
        ];
        description = "Sets from catalog.nix to keep: ${setList}.";
      };
      setDirs = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          books-all = "/mnt/big/kiwix";
        };
        description = "Keep these sets on another drive instead of `dir`.";
      };
      extraBooks = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "wikipedia_de_all_maxi" ];
        description = "More Kiwix catalog ids (`<name>` or `<name>_<flavour>`), kept in `dir`.";
      };
      shelf = mkOption {
        type = types.str;
        default = "${cfg.kiwix.dir}/all-books";
        defaultText = lib.literalExpression ''"''${config.zi.offline.kiwix.dir}/all-books"'';
        description = "A directory of links to every finished book, whichever drive it is on: the Kiwix desktop app's monitor directory (it can watch only one).";
      };
      port = mkOption {
        type = types.port;
        default = 8092;
        description = "kiwix-serve's port on 127.0.0.1; the hub serves it at /library.";
      };
    };

    maps = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Download the Protomaps planet basemap and serve it at /maps.";
      };
      dir = mkOption {
        type = types.str;
        description = "Where the planet map (planet.pmtiles) is kept.";
      };
      refreshDays = mkOption {
        type = types.ints.positive;
        default = 90;
        description = "Download a newer planet only once the copy is this many days behind the newest build.";
      };
    };

    ai = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Open WebUI on the local models, with the library as a tool.";
      };
      port = mkOption {
        type = types.port;
        default = 8091;
        description = "Open WebUI's port.";
      };
      models = mkOption {
        type = types.listOf types.str;
        default = [
          "qwen3.6:35b-a3b"
          "gpt-oss:20b"
          # reads photos: labels, plants, injuries (attach an image in a chat)
          "qwen3-vl:8b"
        ];
        description = "Ollama models to keep pulled for offline use.";
      };
      embeddingModel = mkOption {
        type = types.str;
        default = "bge-m3";
        description = "Ollama embedding model Open WebUI uses for uploaded documents (multilingual).";
      };
      openaiUrls = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "http://127.0.0.1:8080/v1" ];
        description = "OpenAI-compatible endpoints (llama.cpp servers) Open WebUI offers as well.";
      };
      toolsPort = mkOption {
        type = types.port;
        default = 8093;
        description = "Port of the library tool server on 127.0.0.1.";
      };
    };

    hub.port = mkOption {
      type = types.port;
      default = 8090;
      description = "Port of the hub page (library, maps, CyberChef).";
    };

    docs = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Keep the documents in catalog.nix (the national crisis brochure, Where There Is No Doctor) and serve them at /docs.";
      };
      dir = mkOption {
        type = types.str;
        default = "${dirOf cfg.kiwix.dir}/docs";
        defaultText = lib.literalExpression ''"''${dirOf config.zi.offline.kiwix.dir}/docs"'';
        description = "Where the documents are kept.";
      };
      extra = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          "Local/Evacuation map.pdf" = "https://example.org/evacuation.pdf";
        };
        description = "More documents to keep, as path = URL.";
      };
    };

    apps = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Keep Android apps (APKs) and serve them at /apps, so a phone can install them with no internet.";
      };
      dir = mkOption {
        type = types.str;
        default = "${dirOf cfg.kiwix.dir}/apps";
        defaultText = lib.literalExpression ''"''${dirOf config.zi.offline.kiwix.dir}/apps"'';
        description = "Where the APKs are kept.";
      };
      abi = mkOption {
        type = types.str;
        default = "arm64-v8a";
        description = "The phones' CPU type: picks the build of apps that F-Droid builds per CPU.";
      };
      fdroid = mkOption {
        type = types.listOf types.str;
        default = catalog.apps.fdroid;
        description = "F-Droid package ids to keep (newest build, checked against F-Droid's index).";
      };
      direct = mkOption {
        type = types.attrsOf types.str;
        default = catalog.apps.direct;
        description = "Other APKs, as file name = URL.";
      };
    };

    navigation = {
      enable = lib.mkEnableOption "place search and directions on the hub's map (Photon and Valhalla, from OpenStreetMap)";
      regions = mkOption {
        type = types.listOf types.str;
        default = [ "europe/sweden" ];
        example = [
          "europe/sweden"
          "europe/norway"
        ];
        description = "Geofabrik regions (`continent/country`) to search and route in: about 1 GB of downloads and a few GB on disk per country.";
      };
      dir = mkOption {
        type = types.str;
        default = "${dirOf cfg.kiwix.dir}/navigation";
        defaultText = lib.literalExpression ''"''${dirOf config.zi.offline.kiwix.dir}/navigation"'';
        description = "Where the OpenStreetMap extracts, the routing tiles and the place index are kept.";
      };
      languages = mkOption {
        type = types.listOf types.str;
        default = [
          "en"
          "sv"
        ];
        description = "Languages place names can be searched in, besides the local names.";
      };
      routingPort = mkOption {
        type = types.port;
        default = 8002;
        description = "Valhalla's port on 127.0.0.1; the hub serves it at /nav/route.";
      };
      searchPort = mkOption {
        type = types.port;
        default = 2322;
        description = "Photon's port on 127.0.0.1; the hub serves it at /nav/search and /nav/reverse.";
      };
    };

    meshtastic = {
      enable = mkOption {
        type = types.bool;
        default = cfg.comms.enable;
        defaultText = lib.literalExpression "config.zi.offline.comms.enable";
        description = "Serve the Meshtastic web client: message over a LoRa node from any browser, no internet.";
      };
      port = mkOption {
        type = types.port;
        default = 8094;
        description = "Port of the Meshtastic web client (it can't live under the hub's path).";
      };
    };

    lan.interfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "enp3s0"
        "tailscale0"
      ];
      description = "Interfaces other devices may reach the hub and the AI on. Empty: this machine only.";
    };

    archive = {
      cacheDir = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Offline Nix binary cache of this system and its flake's inputs, so it can be rebuilt or reinstalled with no internet.";
      };
      flake = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Checkout of this system's flake: its inputs go into the cache.";
      };
      bundle = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Where to keep a git bundle (all history, one file) of `flake`.";
      };
      models = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          "/var/lib/ollama/models" = "/mnt/archive/models/ollama";
        };
        description = "Model directories to mirror onto the archive drive, as source = destination.";
      };
      onCalendar = mkOption {
        type = types.str;
        default = "weekly";
        description = "When to refresh the archive (systemd OnCalendar).";
      };
    };

    desktop.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install the desktop apps: the Kiwix reader and CoMaps (offline maps with search and routing; regions are downloaded in the app).";
    };

    comms.enable = lib.mkEnableOption "radio and mesh tools: JS8Call, Fldigi, WSJT-X, CHIRP, Direwolf, SDR++, Gqrx, rtl-sdr and the Meshtastic CLI";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = [
        offline.offline-sync
      ]
      ++ optionals cfg.desktop.enable [
        pkgs.kiwix
        pkgs.comaps
      ];

      # The desktop reader keeps its own library: by default it watches the
      # shelf of links, so every book appears in it (Qt reads this system-wide
      # file for any setting the user hasn't set in the app)
      environment.etc."xdg/kiwix-desktop/Kiwix-desktop.conf" =
        mkIf (cfg.desktop.enable && cfg.kiwix.enable)
          {
            text = ''
              [monitor]
              dir=${cfg.kiwix.shelf}
            '';
          };

      # the sync's settings, for running `offline-sync status` by hand
      environment.variables.OFFLINE_CONFIG = "${syncConfig}";

      systemd.services.offline-sync = {
        description = "Download new releases of the offline library and map";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        unitConfig.RequiresMountsFor = dataDirs;
        environment.OFFLINE_CONFIG = "${syncConfig}";
        # a switch must not restart (and then wait out) a download that runs
        # for hours; the new code takes over on the next run
        restartIfChanged = false;
        serviceConfig = userJob // {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.group;
          StateDirectory = "offline-sync";
          StateDirectoryMode = "0755";
          ProtectHome = true;
          # an empty library first, so kiwix-serve is up while the books arrive
          ExecStartPre = [
            "${offline.offline-sync}/bin/offline-sync prepare"
          ]
          ++ optional cfg.kiwix.enable "+${pkgs.systemd}/bin/systemctl start --no-block kiwix-serve.service";
          ExecStart = "${offline.offline-sync}/bin/offline-sync all";
          # the first run downloads hundreds of GB
          TimeoutStartSec = "infinity";
        };
      };

      systemd.timers.offline-sync = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.sync.onCalendar;
          Persistent = true;
          RandomizedDelaySec = "6h";
        };
      };

      services.caddy = {
        enable = true;
        # plain `handle` blocks only: Caddy tries them longest path first and
        # the catch-all last (handle_path sorts apart from handle)
        virtualHosts."http://:${toString cfg.hub.port}".extraConfig = ''
          redir /maps /maps/
          redir /cyberchef /cyberchef/
          handle /library* {
            reverse_proxy 127.0.0.1:${toString cfg.kiwix.port}
          }
          handle /maps/data/* {
            uri strip_prefix /maps/data
            root * ${cfg.maps.dir}
            file_server
          }
          handle /maps/* {
            uri strip_prefix /maps
            root * ${offline.offline-maps-viewer}
            file_server
          }
          handle /cyberchef/* {
            uri strip_prefix /cyberchef
            root * ${pkgs.cyberchef}/share/cyberchef
            file_server
          }
          ${lib.optionalString cfg.docs.enable ''
            redir /docs /docs/
            handle /docs/* {
              uri strip_prefix /docs
              root * ${cfg.docs.dir}
              file_server browse
            }
          ''}
          ${lib.optionalString cfg.apps.enable ''
            redir /apps /apps/
            handle /apps/* {
              uri strip_prefix /apps
              root * ${cfg.apps.dir}
              # phones offer to install, rather than save, a file with this type
              header *.apk Content-Type application/vnd.android.package-archive
              file_server browse
            }
          ''}
          ${lib.optionalString cfg.navigation.enable ''
            handle /nav/route {
              rewrite * /route
              reverse_proxy 127.0.0.1:${toString cfg.navigation.routingPort}
            }
            handle /nav/search {
              rewrite * /api?{query}
              reverse_proxy 127.0.0.1:${toString cfg.navigation.searchPort}
            }
            handle /nav/reverse {
              rewrite * /reverse?{query}
              reverse_proxy 127.0.0.1:${toString cfg.navigation.searchPort}
            }
          ''}
          handle /status.json {
            root * ${stateDir}
            file_server
          }
          handle /config.json {
            root * ${hubConfig}
            file_server
          }
          handle {
            root * ${offline.offline-hub}
            file_server
          }
        '';
      };

      # By user, not session: terminals and desktop shells often run as
      # systemd user services, outside the login session, where polkit sees no
      # active session. The unit list is what keeps this narrow.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          var units = ${builtins.toJSON units};
          if (action.id == "org.freedesktop.systemd1.manage-units"
              && subject.user == "${cfg.user}"
              && units.indexOf(action.lookup("unit")) >= 0) {
            return polkit.Result.YES;
          }
        });
      '';
    }

    (mkIf cfg.kiwix.enable {
      services.kiwix-serve = {
        enable = true;
        address = "127.0.0.1";
        inherit (cfg.kiwix) port;
        libraryPath = library;
        extraArgs = [
          "--monitorLibrary"
          "--urlRootLocation"
          "/library"
        ];
      };
      # until the first sync writes library.xml there is nothing to serve;
      # the sync starts it then
      systemd.services.kiwix-serve.unitConfig = {
        RequiresMountsFor = kiwixDirs;
        ConditionPathExists = library;
      };
    })

    (mkIf cfg.ai.enable {
      services.ollama = {
        enable = lib.mkDefault true;
        loadModels = cfg.ai.models ++ [ cfg.ai.embeddingModel ];
      };

      services.open-webui = {
        enable = true;
        host = if cfg.lan.interfaces != [ ] then "0.0.0.0" else "127.0.0.1";
        inherit (cfg.ai) port;
        environment = {
          OLLAMA_BASE_URL = "http://127.0.0.1:${toString config.services.ollama.port}";
          ENABLE_OPENAI_API = if cfg.ai.openaiUrls != [ ] then "True" else "False";
          OPENAI_API_BASE_URLS = lib.concatStringsSep ";" cfg.ai.openaiUrls;
          OPENAI_API_KEYS = lib.concatStringsSep ";" (map (_: "none") cfg.ai.openaiUrls);
          # nothing is fetched from the internet: documents are embedded by Ollama
          OFFLINE_MODE = "True";
          RAG_EMBEDDING_ENGINE = "ollama";
          RAG_EMBEDDING_MODEL = cfg.ai.embeddingModel;
          ENABLE_WEB_SEARCH = "False";
          ANONYMIZED_TELEMETRY = "False";
          DO_NOT_TRACK = "True";
          SCARF_NO_ANALYTICS = "True";
          # seeded on first start; changes made in the admin panel then persist
          TOOL_SERVER_CONNECTIONS = builtins.toJSON (
            optional cfg.kiwix.enable {
              type = "openapi";
              url = "http://127.0.0.1:${toString cfg.ai.toolsPort}";
              path = "openapi.json";
              spec_type = "url";
              auth_type = "none";
              key = "";
              config = {
                enable = true;
                # every account may use it, not only the admin
                access_grants = [
                  {
                    principal_type = "user";
                    principal_id = "*";
                    permission = "read";
                  }
                ];
              };
              info = {
                id = "offline-library";
                name = "Offline library";
                description = "Search and read the offline library (Wikipedia, medicine, survival and repair guides, books).";
              };
            }
          );
        };
      };

      systemd.services.open-webui = {
        after = [ "ollama.service" ];
        wants = [ "ollama.service" ];
      };

      systemd.services.offline-library-tools = mkIf cfg.kiwix.enable {
        description = "Library tools for Open WebUI: search and read the Kiwix library";
        wantedBy = [ "multi-user.target" ];
        after = [ "kiwix-serve.service" ];
        environment = {
          KIWIX_URL = "http://127.0.0.1:${toString cfg.kiwix.port}/library";
          HOST = "127.0.0.1";
          PORT = toString cfg.ai.toolsPort;
        };
        serviceConfig = sandbox // {
          ExecStart = "${offline.offline-library-tools}/bin/offline-library-tools";
          DynamicUser = true;
          ProtectHome = true;
          MemoryDenyWriteExecute = true;
          CapabilityBoundingSet = [ "" ];
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          Restart = "on-failure";
          RestartSec = 5;
          Nice = 0;
        };
      };
    })

    (mkIf (cfg.archive.cacheDir != null || cfg.archive.models != { }) {
      systemd.services.offline-archive = {
        description = "Archive this system's Nix closure, flake inputs and models for offline use";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        unitConfig.RequiresMountsFor = archiveDirs;
        environment = {
          OFFLINE_CONFIG = "${syncConfig}";
          XDG_CACHE_HOME = "/var/cache/offline-archive";
        };
        # like offline-sync: a switch leaves a running archive alone
        restartIfChanged = false;
        path = [ config.nix.package ];
        serviceConfig = userJob // {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.group;
          CacheDirectory = "offline-archive";
          # reads the flake checkout
          ProtectHome = "read-only";
          ExecStart = [
            "${offline.offline-sync}/bin/offline-sync archive"
          ]
          # model stores belong to their services: copied as root, then owned by the user
          ++ lib.mapAttrsToList (
            source: destination:
            "+${pkgs.rsync}/bin/rsync -a --delete --mkpath --chown=${cfg.user}:${cfg.group} ${source}/ ${destination}/"
          ) cfg.archive.models;
          TimeoutStartSec = "infinity";
        };
      };

      systemd.timers.offline-archive = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.archive.onCalendar;
          Persistent = true;
          RandomizedDelaySec = "2h";
        };
      };
    })

    (mkIf cfg.comms.enable {
      environment.systemPackages = with pkgs; [
        js8call
        fldigi
        wsjtx
        chirp
        direwolf
        sdrpp
        gqrx
        rtl-sdr
        meshtastic
      ];
      # udev rules for RTL-SDR dongles; plugdev for those, dialout for
      # serial radios and Meshtastic nodes over USB
      hardware.rtl-sdr.enable = true;
      users.users.${cfg.user}.extraGroups = [
        "plugdev"
        "dialout"
      ];
    })

    # Directions and place search for the map. offline-sync downloads the
    # OpenStreetMap data and builds both databases, then restarts these; until
    # the first build they have nothing to serve and don't start.
    (mkIf cfg.navigation.enable (
      let
        server = {
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = userJob // {
            User = cfg.user;
            Group = cfg.group;
            ProtectHome = true;
            Restart = "on-failure";
            RestartSec = 10;
            # they answer people, unlike the background jobs
            Nice = 0;
            IOSchedulingClass = "best-effort";
          };
        };
      in
      {
        systemd.services.offline-routing = lib.recursiveUpdate server {
          description = "Offline directions (Valhalla) for the hub's map";
          unitConfig = {
            RequiresMountsFor = [ cfg.navigation.dir ];
            ConditionPathExists = "${cfg.navigation.dir}/valhalla/valhalla.json";
          };
          serviceConfig.ExecStart = "${offline.valhalla}/bin/valhalla_service ${cfg.navigation.dir}/valhalla/valhalla.json 2";
        };

        systemd.services.offline-search = lib.recursiveUpdate server {
          description = "Offline place search (Photon) for the hub's map";
          unitConfig = {
            RequiresMountsFor = [ cfg.navigation.dir ];
            ConditionPathExists = "${cfg.navigation.dir}/photon/photon_data";
          };
          environment.JAVA_OPTS = "-Xmx1g";
          serviceConfig.ExecStart = lib.concatStringsSep " " [
            "${offline.offline-photon}/bin/offline-photon serve"
            "-data-dir ${cfg.navigation.dir}/photon"
            "-listen-ip 127.0.0.1"
            "-listen-port ${toString cfg.navigation.searchPort}"
          ];
        };
      }
    ))

    # The client loads from /, so it gets its own port. From another device
    # it can reach a node over Wi-Fi (HTTP); USB and Bluetooth need a secure
    # page, which over plain HTTP only this machine's own browser is.
    (mkIf cfg.meshtastic.enable {
      services.caddy.virtualHosts."http://:${toString cfg.meshtastic.port}".extraConfig = ''
        root * ${pkgs.meshtastic-web}
        try_files {path} /index.html
        file_server
      '';
    })

    (mkIf (cfg.lan.interfaces != [ ]) {
      networking.firewall.interfaces = lib.genAttrs cfg.lan.interfaces (_: {
        allowedTCPPorts = [
          cfg.hub.port
        ]
        ++ optional cfg.ai.enable cfg.ai.port
        ++ optional cfg.meshtastic.enable cfg.meshtastic.port;
      });
    })
  ]);
}
