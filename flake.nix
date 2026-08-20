{
  description = "NixOS — KDE Plasma 6 + Hyprland + dotfiles";

  inputs = {

    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    nixpkgs.follows = "chaotic/nixpkgs";

    helium = {
      url = "github:FKouhai/helium2nix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      inputs.home-manager.follows = "home-manager";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-nixcord.follows = "nixpkgs";
    };

    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zls = {
      url = "github:zigtools/zls";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    typix = {
      url = "github:loqusion/typix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      hyprland,
      zen-browser,
      chaotic,
      ...
    }:
    let
      system = "x86_64-linux";
      hostname = "nixos";
      username = "ziad0dev";
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit
            inputs
            username
            hostname
            system
            ;
        };

        modules = [
          ./hosts/nixos/hardware-configuration.nix
          ./hosts/nixos/configuration.nix
          ./modules/virt.nix
          ./modules/gaming.nix
          ./modules/llm.nix
          ./modules/ollama.nix
          ./modules/davinci.nix
          ./modules/audio.nix
          ./modules/dev.nix
          ./modules/gaming-extras.nix
          ./modules/recording.nix
          ./modules/media.nix
          ./modules/mullvad.nix
          ./modules/media-extras.nix
          ./modules/performance.nix
          ./modules/secrets.nix
          ./modules/storage.nix
          ./modules/hdr.nix
          ./modules/dev-langs.nix
          ./modules/waybar-lua-fix.nix
          ./modules/ananicy-fix.nix
          ./modules/lockscreen.nix

          chaotic.nixosModules.nyx-cache
          chaotic.nixosModules.nyx-overlay
          chaotic.nixosModules.nyx-registry

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = { inherit inputs username system; };
            home-manager.users.${username} = import ./home/home.nix;
          }
        ];
      };

      nixosConfigurations.claude-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs system;
          username = "dev";
          hostname = "claude-vm";
        };

        modules = [ ./hosts/claude-vm ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      templates = {
        zig = {
          path = ./templates/zig;
          description = "Zig (zig-overlay) + zls";
        };
        rust = {
          path = ./templates/rust;
          description = "Rust stable + rust-analyzer";
        };
        haskell = {
          path = ./templates/haskell;
          description = "GHC + HLS (+ Clash, commented)";
        };
        beam = {
          path = ./templates/beam;
          description = "Elixir OTP-matched + elixir-ls";
        };
        c = {
          path = ./templates/c;
          description = "C/C++ clangStdenv + clangd + mold + bear";
        };
        lisp = {
          path = ./templates/lisp;
          description = "SBCL + ocicl (project-local systems)";
        };
        python = {
          path = ./templates/python;
          description = "Python nix-first + uv escape hatch";
        };
        typst = {
          path = ./templates/typst;
          description = "Typst + typix reproducible builds";
        };
        latex = {
          path = ./templates/latex;
          description = "LaTeX latexmk + reproducible nix build";
        };
      };
    };
}
