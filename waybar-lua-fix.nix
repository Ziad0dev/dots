{ config, lib, pkgs, ... }:

# TEMPORARY — delete this file (and its flake.nix entry) once nixpkgs ships
# a waybar release newer than 0.15.0.
#
# waybar 0.15.0 sends legacy "dispatch workspace N" IPC strings, which
# Hyprland's Lua dispatcher can't parse (Waybar #5008) — workspace clicks
# do nothing. Master is fixed: IPC::dispatch detects the Lua protocol and
# builds hl.dsp-form dispatches. So: same package expression, master source.

{
  nixpkgs.overlays = [
    (final: prev: {
      waybar = prev.waybar.overrideAttrs (old: {
        version = "0.15.0-lua-ipc-fix";
        src = final.fetchFromGitHub {
          owner = "Alexays";
          repo = "Waybar";
          rev = "30610d3b68f109e950d924bc7d9c42b8cbbc5df8";
          # Fake hash on purpose: the first build fails and prints the real
          # one — paste it here, rebuild. One round trip.
          hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        };
      });
    })
  ];
}
