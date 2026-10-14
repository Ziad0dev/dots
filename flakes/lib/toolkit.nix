# Shared plumbing for the curated toolkit subflakes (infosec, maths): name
# resolution, the NixOS/home-manager module and the standalone flake outputs.
# Each toolkit keeps only its names.nix and whatever is specific to it.
{
  # names.nix -> { names, lookup, sets, missing }. A name is an attr path in
  # pkgs ("python3Packages.pwntools"); `overrides` maps a name to a configured
  # build instead, `extra` appends packages to a set. Names that don't
  # evaluate or aren't available on the platform are dropped, and reported
  # in `missing`. Each name is looked up once.
  mkPackages =
    {
      lib,
      pkgs,
      names,
      overrides ? { },
      extra ? { },
    }:
    let
      try =
        e:
        let
          r = builtins.tryEval e;
        in
        if r.success then r.value else null;
      lookup = n: try (overrides.${n} or (lib.attrByPath (lib.splitString "." n) null pkgs));
      usable = p: p != null && lib.defaultTo false (try (p.meta.available or true));
      resolved = lib.mapAttrs (
        _:
        map (n: {
          inherit n;
          p = lookup n;
        })
      ) names;
      ok = lib.mapAttrs (_: lib.filter (r: usable r.p)) resolved;
    in
    {
      inherit names lookup;
      sets = lib.mapAttrs (s: rs: map (r: r.p) rs ++ (extra.${s} or [ ])) ok;
      missing = lib.mapAttrs (_: rs: map (r: r.n) (lib.filter (r: !(usable r.p)) rs)) resolved;
    };

  # options.zi.<name> = { enable, sets, exclude, extraPackages }, installed
  # system-wide (target = "nixos") or per user (target = "home").
  mkModule =
    {
      name,
      description,
      packages,
    }:
    { target }:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.zi.${name};
      p = import packages { inherit lib pkgs; };
      excluded = lib.filter (x: x != null) (map p.lookup cfg.exclude);
      # a tool listed in two chosen sets (gdb: binary + pwn) goes in once
      chosen =
        lib.unique (lib.filter (pkg: !(lib.elem pkg excluded)) (lib.concatMap (s: p.sets.${s}) cfg.sets))
        ++ cfg.extraPackages;
    in
    {
      options.zi.${name} = {
        enable = lib.mkEnableOption description;

        sets = lib.mkOption {
          type = lib.types.listOf (lib.types.enum (lib.attrNames p.sets));
          default = [ "core" ];
        };

        # names (as in names.nix) to leave out of the chosen sets, e.g. one
        # that doesn't build on the current nixpkgs
        exclude = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
        };
      };

      config = lib.mkIf cfg.enable (
        if target == "nixos" then { environment.systemPackages = chosen; } else { home.packages = chosen; }
      );
    };

  # Standalone outputs: packages.<set> (buildEnv), devShells.<set>, `all`,
  # an `audit` app listing names missing from this nixpkgs, and the modules.
  # nixpkgs is imported once per system and shared by every output.
  mkFlake =
    {
      self,
      nixpkgs,
      name,
      systems,
      packages,
      module,
      extraShells ? (_pkgs: _p: { }),
    }:
    let
      inherit (nixpkgs) lib;
      pkgsFor = lib.genAttrs systems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );
      loaded = lib.mapAttrs (
        _: pkgs:
        import packages {
          inherit (pkgs) lib;
          inherit pkgs;
        }
      ) pkgsFor;
      each = f: lib.mapAttrs (system: pkgs: f pkgs loaded.${system}) pkgsFor;
      all = p: lib.unique (lib.concatLists (builtins.attrValues p.sets));
    in
    {
      packages = each (
        pkgs: p:
        let
          env =
            set: paths:
            pkgs.buildEnv {
              name = "${name}-${set}";
              inherit paths;
              ignoreCollisions = true;
            };
          report = pkgs.writeText "${name}-missing" (
            lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                n: ms: "${n}: ${if ms == [ ] then "ok" else lib.concatStringsSep " " ms}"
              ) p.missing
            )
          );
        in
        lib.mapAttrs env p.sets
        // {
          default = env "core" p.sets.core;
          all = env "all" (all p);
          audit = pkgs.writeShellScriptBin "${name}-audit" "cat ${report}";
        }
      );

      devShells = each (
        pkgs: p:
        let
          shell =
            set: paths:
            pkgs.mkShellNoCC {
              name = "${name}-${set}";
              packages = paths;
            };
        in
        lib.mapAttrs shell p.sets
        // {
          default = shell "core" p.sets.core;
          all = shell "all" (all p);
        }
        // extraShells pkgs p
      );

      apps = lib.genAttrs systems (system: {
        audit = {
          type = "app";
          program = "${self.packages.${system}.audit}/bin/${name}-audit";
        };
      });

      nixosModules.default = module { target = "nixos"; };
      homeManagerModules.default = module { target = "home"; };

      formatter = lib.mapAttrs (_: pkgs: pkgs.nixfmt-tree) pkgsFor;
    };
}
