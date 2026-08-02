{ config, lib, pkgs, username, ... }:

{
  # ── Mullvad ───────────────────────────────────────────────────────────────
  services.mullvad-vpn = {
    enable = true;
    # The daemon and the GUI are separate packages now — setting `package` to
    # pkgs.mullvad-vpn breaks the daemon assertion, since that derivation no
    # longer ships one. Leave `package` alone and ask for the GUI here.
    gui.enable = true;
  };

  # Mullvad ships its own DNS handling and expects to drive resolved rather
  # than fight NetworkManager over /etc/resolv.conf. Without this, DNS leaks
  # or breaks outright when the tunnel comes up.
  services.resolved.enable = true;

  # ── Living alongside Tailscale ────────────────────────────────────────────
  # Both are WireGuard tunnels, and Mullvad's kill switch ("Block connections
  # without VPN", on by default) drops everything outside its tunnel —
  # including tailscale0. Symptom: Jellyfin becomes unreachable from the phone
  # the moment Mullvad connects, and `tailscale ping` times out.
  #
  # Three ways to handle it, in order of how well they work:
  #
  #   1. Split tunnelling. Mullvad on Linux excludes traffic by cgroup:
  #        mullvad split-tunnel add <pid-or-cgroup>
  #      The GUI has an app list under Settings -> Split tunneling. Excluding
  #      tailscaled keeps the tailnet up while everything else is tunnelled.
  #      This is the one to reach for.
  #
  #   2. Tailscale's own Mullvad exit nodes. Tailscale sells Mullvad access as
  #      an add-on; you then pick a Mullvad exit node from inside Tailscale and
  #      run a single tunnel instead of two stacked ones. Cleanest by far, but
  #      it's a separate subscription from a standalone Mullvad account.
  #
  #   3. Turn the kill switch off (Settings -> Advanced). Simplest, and it
  #      gives up the thing the kill switch is for — if the tunnel drops,
  #      traffic silently falls back to your normal connection.
  #
  # Nothing here configures any of the three; they're runtime settings the
  # daemon persists in /etc/mullvad-vpn.

  # Local traffic stays local. Without this, LAN devices are unreachable while
  # connected — which would break Jellyfin playback to anything on
  # 192.168.86.0/24 (see [[network]] for why the desktop sits there).
  #   mullvad lan set allow
  # is the runtime equivalent; there is no Nix option for it.

  # ── Notes ─────────────────────────────────────────────────────────────────
  #   mullvad account login <number>     first-run auth
  #   mullvad connect / disconnect
  #   mullvad status
  #   mullvad lan set allow              reach 192.168.86.x while connected
  #   mullvad relay set location se sto  pin an exit location
  #   mullvad tunnel set ipv6 off        you have no global IPv6 anyway
  #
  # The daemon starts at boot and reconnects automatically. If you'd rather it
  # not auto-connect:
  #   mullvad auto-connect set off
}
