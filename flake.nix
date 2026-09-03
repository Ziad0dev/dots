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

    dvr-patched = {
      url = "git+https://git.sljusard.com/sljusard/dvr-patched-flake.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-preview-share-picker = {
      url = "git+https://github.com/WhySoBad/hyprland-preview-share-picker?submodules=1";
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
      inputs.nixpkgs-nixcord.follows = "nixpkgs";
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
        chaotic.nixosModules.nyx-registry
      ];

      desktopModules = [
        inputs.vpn-confinement.nixosModules.default
        ./modules/lan.nix
        ./modules/vpn.nix
        ./modules/quality.nix
        ./modules/backup.nix
        ./modules/virt.nix
        ./modules/gaming.nix
        ./modules/llm.nix
        ./modules/ollama.nix
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
        ./modules/ananicy-fix.nix
        ./modules/osd.nix
        ./modules/lockscreen.nix
        ./modules/sddm.nix
        ./modules/foreign.nix
        ./modules/flatpak.nix
      ];
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

        claude-vm = mk.nixos {
          hostname = "claude-vm";
          username = "dev";
          system = "x86_64-linux";
          home = false;
          modules = [ ./hosts/claude-vm ];
        };
      };

      darwinConfigurations.mac = mk.darwin {
        inherit username;
        hostname = "mac";
        system = "aarch64-darwin";
        profile = "desktop";
        modules = [ ./hosts/darwin ];
      };

      homeConfigurations = {

        "${username}@mac" = mk.home {
          inherit username;
          system = "aarch64-darwin";
          profile = "desktop";
        };

        "${username}@linux" = mk.home {
          inherit username;
          system = "x86_64-linux";
          profile = "minimal";
        };

        "${username}@linux-desktop" = mk.home {
          inherit username;
          system = "x86_64-linux";
          profile = "desktop";
        };

        "${username}@aarch64-linux" = mk.home {
          inherit username;
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
