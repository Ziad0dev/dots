{
  description = "dots — NixOS, nix-darwin, and standalone home-manager";

  inputs = {

    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    chaotic.inputs.home-manager.follows = "home-manager";

    nixpkgs.follows = "chaotic/nixpkgs";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
    # Secure Boot (modules/secureboot.nix); a release tag, as upstream recommends
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-preview-share-picker = {
      # url = "git+https://github.com/WhySoBad/hyprland-preview-share-picker?submodules=1";
      url = "git+https://github.com/WhySoBad/hyprland-preview-share-picker?submodules=1&ref=drop-hyprland-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    vpn-confinement = {
      url = "github:Maroka-chan/VPN-Confinement";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-packages.follows = "nixpkgs";
      inputs.nixpkgs-ci.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      inputs.nix-darwin.follows = "nix-darwin";
    };

    obsidian-extensions = {
      url = "github:karaolidis/nix-obsidian-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zls = {
      url = "github:zigtools/zls/0.16.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # no nixpkgs follows: keeps numtide's binary cache hitting
    llm-agents.url = "github:numtide/llm-agents.nix";

    vm-curator = {
      url = "github:mroboff/vm-curator";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      chaotic,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      mk = import ./lib/mk.nix { inherit inputs lib; };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAll = lib.genAttrs systems;

      username = "ziad0dev";

      chaoticModules = [
        chaotic.nixosModules.nyx-cache
        chaotic.nixosModules.nyx-overlay
      ];

      # every file under modules/ is a desktop NixOS module, so adding one is just
      # creating the file (git add it — untracked files are invisible to the flake)
      desktopModules = [
        inputs.vpn-confinement.nixosModules.default
      ]
      ++ builtins.filter (lib.hasSuffix ".nix") (lib.filesystem.listFilesRecursive ./modules);

    in
    {
      nixosConfigurations = {

        nixos = mk.nixos {
          inherit username;
          hostname = "nixos";
          system = "x86_64-linux";
          profile = "desktop";
          modules = [
            ./hosts/nixos/hardware-configuration.nix
            ./hosts/nixos/configuration.nix
          ]
          ++ desktopModules
          ++ chaoticModules;
        };
      };

      darwinConfigurations.mac = mk.darwin {
        inherit username;
        hostname = "mac";
        system = "aarch64-darwin";
        profile = "desktop";
        modules = [ ./hosts/darwin ];
      };

      homeConfigurations = lib.mapAttrs (name: args: mk.home ({ inherit name username; } // args)) {

        "${username}@mac" = {
          system = "aarch64-darwin";
          profile = "desktop";
        };

        "${username}@linux" = {
          system = "x86_64-linux";
          profile = "minimal";
        };

        "${username}@linux-desktop" = {
          system = "x86_64-linux";
          profile = "desktop";
        };

        "${username}@aarch64-linux" = {
          system = "aarch64-linux";
          profile = "minimal";
        };
      };

      formatter = forAll (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      templates = {
        zig = {
          path = ./templates/zig;
          description = "Zig — matched zls pairs (default / edge / nightly)";
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
          description = "Typst reproducible builds";
        };
        latex = {
          path = ./templates/latex;
          description = "LaTeX latexmk + reproducible nix build";
        };
      };
    };
}
