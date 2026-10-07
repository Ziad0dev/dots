{ inputs, lib }:

let
  overlays = import ./overlays.nix { inherit inputs; };

  mkPkgs =
    system:
    import inputs.nixpkgs {
      inherit system overlays;
      config.allowUnfree = true;
    };

  hmShared =
    {
      username,
      system,
      profile,
      homeModule,
    }:
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "backup";
      # an app rewriting a managed file (mimeapps.list) a second time would
      # otherwise find the old .backup in the way and fail the activation
      home-manager.overwriteBackup = true;
      home-manager.extraSpecialArgs = {
        inherit
          inputs
          username
          system
          profile
          ;
        standalone = false;
        hmConfigName = null;
      };
      home-manager.users.${username} = import homeModule;
    };

  hmNixos = args: [
    inputs.home-manager.nixosModules.home-manager
    (hmShared args)
  ];
in
{
  # home-manager riding on a NixOS system, for configs not built by mk.nixos
  # (the VM test in tests/vm.nix)
  inherit hmNixos;

  nixos =
    {
      hostname,
      username,
      system ? "x86_64-linux",
      profile ? "desktop",
      modules ? [ ],
      homeModule ? ../home/home.nix,
      home ? true,
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit
          inputs
          username
          hostname
          system
          profile
          ;
      };
      modules =
        modules
        ++ lib.optionals home (hmNixos {
          inherit
            username
            system
            profile
            homeModule
            ;
        });
    };

  darwin =
    {
      hostname,
      username,
      system ? "aarch64-darwin",
      profile ? "desktop",
      modules ? [ ],
      homeModule ? ../home/home.nix,
    }:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit
          inputs
          username
          hostname
          system
          profile
          ;
      };
      modules = modules ++ [
        inputs.home-manager.darwinModules.home-manager
        (hmShared {
          inherit
            username
            system
            profile
            homeModule
            ;
        })
      ];
    };

  # `name` is the homeConfigurations attribute, which `nh home switch -c` needs
  home =
    {
      name,
      username,
      system,
      profile ? "minimal",
      repoPath ? null,
      homeDirectory ? null,
      modules ? [ ],
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = mkPkgs system;
      extraSpecialArgs = {
        inherit
          inputs
          username
          system
          profile
          ;
        standalone = true;
        hmConfigName = name;
      };
      modules = [
        ../home/home.nix
      ]
      ++ modules
      ++ lib.optional (repoPath != null) { dots.repoPath = repoPath; }
      ++ lib.optional (homeDirectory != null) { home.homeDirectory = homeDirectory; };
    };
}
