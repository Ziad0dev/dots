# hosts/claude-vm/default.nix
#
# Disposable NixOS guest for running coding agents with permissions off.
# Built from the same nixpkgs as hosts/nixos, so it's mostly store-path reuse.
#
#   ./scripts/claude-vm.sh run
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
    # Defines every virtualisation.* option used below plus
    # config.system.build.vm itself. `nixos-rebuild build-vm` adds this for
    # you; a plain nixpkgs.lib.nixosSystem does not, and without it the eval
    # fails with "option `virtualisation.cores' does not exist".
    "${modulesPath}/virtualisation/qemu-vm.nix"

    ./agent.nix

    # Guest-safe module from this repo. Brings zig/zls, the clang stack,
    # python + uv + pyright, and sbcl with swank — the same toolchains
    # hosts/nixos gets, so the agent works in the environment you do.
    ../../modules/dev-langs.nix

    # NOT importable here, for the record:
    #   dev.nix          pins programs.nh.flake to /home/ziad0dev/dots
    #   virt.nix         libvirtd inside a VM
    #   gaming*.nix      cachyos kernel + nvidia
    #   llm/davinci.nix  CUDA
    #   storage/media*   /data and /mnt mounts that don't exist in the guest
    #   performance.nix  host CPU governor / sysctls
    #   hdr.nix          display pipeline
  ];

  # dev-langs.nix pulls `zigpkgs.master`, which comes from this overlay.
  # hosts/nixos gets it from configuration.nix; the VM needs its own copy.
  nixpkgs.overlays = [ inputs.zig-overlay.overlays.default ];

  networking.hostName = hostname;
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  virtualisation = {
    # Host has 15.4 GiB with zramSwap at 50%. 6 GiB leaves the desktop room;
    # drop to 4096 if Plasma starts swapping while the VM is up.
    memorySize = 6144;
    cores = 4; # i5-12400f is 6C/12T
    diskSize = 24 * 1024; # MiB

    # Serial console. Ctrl-a x powers off, Ctrl-a c opens the QEMU monitor.
    graphics = false;

    # /data/vms is 0771 root:libvirtd per virt.nix, so this is writable.
    diskImage = "/data/vms/claude-vm.qcow2";

    # Overlay over the host store so `nix build` works inside the guest.
    writableStore = true;

    # 9p default msize is 8 KiB, which makes any node_modules tree miserable.
    msize = 262144;

    forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
      # Dev servers, so you can hit what the agent built from the host browser.
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

    # The airlock. 9p passes uids through raw, which is why agent.nix pins
    # the guest user to uid 1001 to match ziad0dev on the host.
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

    # Same registry pinning dev.nix does for the host, minus programs.nh.
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=flake:nixpkgs" ];
  };

  # Saves a few hundred MiB of build on something you throw away.
  documentation.enable = false;
  documentation.nixos.enable = false;

  system.stateVersion = "24.05"; # matches hosts/nixos/configuration.nix
}
