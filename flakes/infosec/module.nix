{ target }:
{ config, lib, pkgs, ... }:
let
  cfg = config.zi.infosec;
  p = import ./packages.nix { inherit lib pkgs; };
  chosen = lib.concatMap (s: p.sets.${s}) cfg.sets ++ cfg.extraPackages;
in
{
  options.zi.infosec = {
    enable = lib.mkEnableOption "curated infosec toolkit";

    sets = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (lib.attrNames p.sets));
      default = [ "core" ];
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable (
    if target == "nixos" then { environment.systemPackages = chosen; }
    else { home.packages = chosen; }
  );
}
