{ config, lib, pkgs, inputs, ... }:

# System-side dev QoL. Wire into flake.nix like gaming.nix / llm.nix.
# Assumes `inputs` comes in via specialArgs — you're already doing that
# for the chaotic modules.

{
  ##########################################################################
  # nh — nixos-rebuild frontend: nix-output-monitor build tree, generation
  # diff on every switch, and it builds as your user (sudo only for the
  # activation step), so no root-owned eval cache.
  ##########################################################################
  programs.nh = {
    enable = true;
    flake = "/home/ziad0dev/dots"; # sets NH_FLAKE → `nh os switch` from anywhere
    clean = {
      enable = true; # replaces nix.gc.automatic — don't enable both
      extraArgs = "--keep 3 --keep-since 4d";
    };
  };

  # (No nix.optimise here — configuration.nix already sets
  # auto-optimise-store, which dedups at write time.)

  # You rebuild from a dirty git tree a dozen times a day; kill the nag.
  nix.settings.warn-dirty = false;

  # Pin the flake registry + NIX_PATH to this flake's nixpkgs, so
  # `nix run nixpkgs#foo`, `nix shell nixpkgs#bar`, and comma all resolve
  # against the exact rev the system was built from (the one following
  # chaotic) instead of hitting the network for a fresh unstable.
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=flake:nixpkgs" ];

  # (nix-ld already enabled in configuration.nix — not repeated here.)
}
