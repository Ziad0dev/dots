{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dots.upstreamWatch;

  watchDir = pkgs.runCommandLocal "dots-upstream-watches" { } (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: w: ''
        mkdir -p "$out/${name}"
        cp ${pkgs.writeText "upstream-watch-${name}-description" w.description} "$out/${name}/description"
        cp ${pkgs.writeText "upstream-watch-${name}-url" w.url} "$out/${name}/url"
        cp ${pkgs.writeShellScript "upstream-watch-${name}-check" w.check} "$out/${name}/check"
        chmod +x "$out/${name}/check"
      '') cfg.watches
    )
  );

  engine = pkgs.writeShellApplication {
    name = "dots-upstream-watch";
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gawk
      git
      gnugrep
      jq
      libnotify
    ];
    text = ''
      export DOTS_UPSTREAM_WATCHES="${watchDir}"
      ${builtins.readFile ../scripts/dots-upstream-watch.sh}
    '';
  };
in
{
  options.dots.upstreamWatch = {
    enable = lib.mkEnableOption "upstream fix watcher read by the Quickshell bar";

    interval = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar expression for the watch timer.";
    };

    watches = lib.mkOption {
      default = { };
      description = ''
        Upstream conditions to poll. Each check runs with the helpers
        raw <owner/repo> <ref> <path>, remote_ref <url> <ref> and
        moved <key> <value> in scope. Exit 0 when the fix has landed,
        1 while still waiting, anything else on error. Anything the
        check prints becomes the detail line in the bar tooltip.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            url = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            check = lib.mkOption { type = lib.types.lines; };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ engine ];

    dots.upstreamWatch.watches.share-picker = {
      description = "hyprland-preview-share-picker: drop-hyprland-rs merged to master";
      url = "https://github.com/WhySoBad/hyprland-preview-share-picker";
      check = ''
        repo=WhySoBad/hyprland-preview-share-picker

        outputs=$(raw "$repo" master src/views/outputs.rs) || {
            echo "cannot reach raw.githubusercontent.com"
            exit 2
        }
        manifest=$(raw "$repo" master Cargo.toml) || {
            echo "cannot reach raw.githubusercontent.com"
            exit 2
        }

        filters=no
        printf '%s' "$outputs" | grep -q 'monitor\.disabled' && filters=yes

        depends=no
        printf '%s' "$manifest" | grep -Eq '^hyprland[[:space:]]*=' && depends=yes

        if [ "$filters" = no ] && [ "$depends" = no ]; then
            echo "master no longer filters monitor.disabled and no longer depends on hyprland-rs"
            echo "set custom_picker_binary back in config/hypr/xdph.conf, then flakeup"
            echo "region command must become lowercase: slurp -f '%o@%x,%y,%w,%h'"
            exit 0
        fi

        head=$(remote_ref "https://github.com/$repo.git" refs/heads/master)
        echo "master ''${head:0:8} still filtering: $filters, hyprland-rs dep: $depends"
        exit 1
      '';
    };

    systemd.user.services.dots-upstream-watch = {
      Unit.Description = "Check whether watched upstream fixes have landed";
      Service = {
        Type = "oneshot";
        ExecStart = "${engine}/bin/dots-upstream-watch notify";
      };
    };

    systemd.user.timers.dots-upstream-watch = {
      Unit.Description = "Poll watched upstream repositories";
      Timer = {
        OnCalendar = cfg.interval;
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
