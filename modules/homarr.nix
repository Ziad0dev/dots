{ config, lib, pkgs, ... }:

# modules/homarr.nix — dashboard for the self-hosted services on this box.
#
# There is no nixpkgs module and no package: Homarr ships as a container only.
# Docker is already enabled in gaming/virt config, so this rides on
# virtualisation.oci-containers rather than pulling in podman as a second
# runtime.
#
# Bound to 127.0.0.1 and reached over the tailnet, same posture as jellyfin,
# radarr and sonarr. Nothing here opens a port on enp5s0.

let
  port = 7575;

  # Homarr keeps its SQLite DB and uploaded icons here. On the LUKS SSD, not
  # the exFAT volume — same reasoning as the *arr databases.
  dataDir = "/var/lib/homarr";
in
{
  virtualisation.oci-containers.containers.homarr = {
    image = "ghcr.io/homarr-labs/homarr:v1.42.0";
    # Pinned rather than :latest. A dashboard silently changing its schema
    # under you during an unrelated rebuild is a bad afternoon; bump this
    # deliberately after reading the release notes.

    ports = [ "127.0.0.1:${toString port}:7575" ];

    volumes = [
      "${dataDir}:/appdata"

      # Lets Homarr discover running containers for its Docker widget. Read-only,
      # but be aware: read access to the docker socket is effectively root on
      # this host, so drop this line if you don't want the widget.
      "/var/run/docker.sock:/var/run/docker.sock:ro"
    ];

    environmentFiles = [ "/var/lib/homarr/secret.env" ];
    # Must contain:
    #   SECRET_ENCRYPTION_KEY=<64 hex chars>
    # Generate once, before the first rebuild:
    #   sudo mkdir -p /var/lib/homarr
    #   printf 'SECRET_ENCRYPTION_KEY=%s\n' "$(openssl rand -hex 32)" \
    #     | sudo tee /var/lib/homarr/secret.env
    #   sudo chmod 600 /var/lib/homarr/secret.env
    #
    # Deliberately NOT in the repo: it encrypts the API keys Homarr stores for
    # jellyfin/radarr/sonarr, so it's a real secret. If you ever want it
    # declarative, that's sops-nix or agenix territory, not a literal here.
    # Losing this file means re-entering every integration's credentials.

    environment = {
      TZ = "Europe/Stockholm";
    };

    extraOptions = [ "--pull=missing" ];
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0700 root root -"
  ];

  # ── Reaching it ───────────────────────────────────────────────────────────
  #   http://100.111.248.58:7575  over the tailnet
  #   http://localhost:7575       on this machine
  #
  # tailscale serve already publishes jellyfin on 443. To put homarr on the
  # tailnet TLS name as well, give it a path:
  #   sudo tailscale serve --bg --set-path /dash 7575
  # which lands it at https://nixos.<tailnet>.ts.net/dash
  #
  # Services to add as integrations once it's up — each wants an API key from
  # that service's own settings page:
  #   jellyfin  http://localhost:8096
  #   radarr    http://localhost:7878
  #   sonarr    http://localhost:8989
  # Use localhost URLs, not the tailnet IP: the container talks to the host,
  # and routing that through tailscale0 is a needless hop.
  #
  # NOTE: the container's own network namespace means "localhost" inside it is
  # the container, not the host. Homarr's integrations therefore need
  # host.docker.internal or the docker bridge address (172.17.0.1) instead —
  # e.g. http://172.17.0.1:8096. docker0 is already up on this box.
}
