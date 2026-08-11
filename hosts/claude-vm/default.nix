
{
  config,
  lib,
  pkgs,
  inputs,
  system,
  hostname,
  modulesPath,
  ...
}:

{
  imports = [

    "${modulesPath}/virtualisation/qemu-vm.nix"

    ./agent.nix

    ../../modules/dev-langs.nix

  ];

  nixpkgs.overlays = [ inputs.zig-overlay.overlays.default ];

  networking.hostName = hostname;
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  virtualisation = {

    memorySize = 6144;
    cores = 4;
    diskSize = 24 * 1024;

    graphics = false;

    diskImage = "/data/vms/claude-vm.qcow2";

    writableStore = true;

    msize = 262144;

    forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }

      {
        from = "host";
        host.port = 5173;
        guest.port = 5173;
      }
      {
        from = "host";
        host.port = 3000;
        guest.port = 3000;
      }
    ];

    sharedDirectories.work = {
      source = "/data/vms/share";
      target = "/mnt/work";
    };
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
      trusted-users = [
        "root"
        "dev"
      ];
    };

    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=flake:nixpkgs" ];
  };

  documentation.enable = false;
  documentation.nixos.enable = false;

  system.stateVersion = "24.05";
}
