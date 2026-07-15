{
  description = "NixOS — KDE Plasma 6 + Hyprland + dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";

    };

    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zls = {
      url = "github:zigtools/zls";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    zls = {
        url = "github:zigtools/zls";
	inputs.nixpkgs.follows = "nixpkgs";
    };

    # dots live at ~/dots as a normal git clone, symlinked live via home.nix.
  };

  outputs = inputs@{ self, nixpkgs, home-manager, hyprland, zen-browser, ... }:
  let
    system   = "x86_64-linux";
    hostname = "nixos";
    username = "ziad0dev";
  in {
    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs username hostname system; };

      modules = [
        ./hardware-configuration.nix
        ./configuration.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs    = true;
          home-manager.useUserPackages  = true;
          # If HM finds an existing file/dir where it wants to put one of its
          # own, it'll rename the existing one with this suffix. If you ever
          # see a *.backup collision error, just delete the old .backup file:
          #   rm ~/.config/foo.backup
          # and rebuild. The stale-dir cleanup script handles the one-time
          # migration so you shouldn't see this in normal use.
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = { inherit inputs username system; };
          home-manager.users.${username} = import ./home.nix;
        }
      ];
    };
  };
}
