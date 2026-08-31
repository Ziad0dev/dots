{ inputs, lib }:

let
  overlays = [ inputs.zig-overlay.overlays.default ];

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
      home-manager.extraSpecialArgs = {
        inherit
          inputs
          username
          system
          profile
          ;
      };
      home-manager.users.${username} = import homeModule;
    };
in
{
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
        ++ lib.optionals home [
          inputs.home-manager.nixosModules.home-manager
          (hmShared { inherit username system profile homeModule; })
        ];
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
        (hmShared { inherit username system profile homeModule; })
      ];
    };

  home =
    {
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
      };
      modules =
        [ ../home/home.nix ]
        ++ modules
        ++ lib.optional (repoPath != null) { dots.repoPath = repoPath; }
        ++ lib.optional (homeDirectory != null) { home.homeDirectory = homeDirectory; };
    };
}
