{
  config,
  username,
  ...
}:

# The offline stack (flakes/offline) on this desktop: the library and the
# archive on the spare drive, the planet map on the media drive. What it
# holds and how to use it with no internet: docs/offline.md.
let
  spare = "/mnt/pool1/offline";
  media = "/mnt/media/offline";
in
{
  imports = [ ../flakes/offline/module.nix ];

  zi.offline = {
    enable = true;
    user = username;

    kiwix = {
      dir = "${spare}/kiwix";
      sets = [
        "survival"
        "medical"
        "encyclopedia"
        "practical"
        "science"
        "computing"
        "survivor-library"
        "books-all"
        "swedish"
      ];
      # the two biggest sets live next to the map
      setDirs = {
        survivor-library = "${media}/kiwix";
        books-all = "${media}/kiwix";
      };
    };

    maps.dir = "${media}/maps";

    # place search and directions on the hub's map
    navigation = {
      enable = true;
      regions = [
        "europe/sweden"
        "europe/norway"
        "europe/finland"
        "europe/denmark"
      ];
    };

    # Open WebUI talks to Ollama; add "http://127.0.0.1:8080/v1" to
    # ai.openaiUrls once modules/llm.nix's units have models to serve

    archive = {
      cacheDir = "${spare}/nix-cache";
      flake = config.dots.repoPath;
      bundle = "${spare}/dots.bundle";
      # Ollama's model data only: its store also holds Ollama's private key
      models = {
        "${config.services.ollama.modelsDir}/blobs" = "${spare}/models/ollama/blobs";
        "${config.services.ollama.modelsDir}/manifests" = "${spare}/models/ollama/manifests";
        "/var/lib/dots/models" = "${spare}/models/gguf";
      };
    };

    lan.interfaces = [
      config.dots.lanInterface
      "tailscale0"
    ];

    comms.enable = true;
  };
}
