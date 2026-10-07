# A small NixOS host for testing the dots end to end: the installer ISO puts
# it on a blank disk (disko), root is a tmpfs (impermanence), the user's
# password comes from secrets/vm.yaml (sops), and home-manager runs the
# minimal profile with config/ copied into the store (liveConfig = false).
# Login: ziad0dev / dots.
{
  config,
  lib,
  inputs,
  username,
  hostname,
  ...
}:

{
  imports = [
    inputs.disko.nixosModules.disko
    (import ../../lib/disko.nix {
      device = "/dev/vda";
      impermanence = true;
    })
    ../../modules/secrets.nix
    ../../modules/impermanence.nix
    ../../modules/quality.nix
    ../../modules/dev.nix
  ];

  networking.hostName = hostname;
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "ahci"
    "sr_mod"
  ];
  # the serial console is how the VM is driven headless (and where the LUKS
  # prompt shows up)
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200"
  ];

  dots.impermanence.enable = true;

  # quality.nix turns smartd on; virtio disks have no SMART, so it would fail
  services.smartd.enable = lib.mkForce false;

  # the installer copies the age key here; /persist is mounted in the initrd,
  # before secrets are decrypted
  dots.secrets = {
    enable = true;
    file = ../../secrets/vm.yaml;
    keyFile = "/persist/var/lib/sops-nix/key.txt";
  };
  sops.secrets.user-password.neededForUsers = true;
  sops.secrets.hello = { };

  programs.fish.enable = true;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = config.programs.fish.package;
    hashedPasswordFile = config.sops.secrets.user-password.path;
  };

  home-manager.users.${username}.dots.liveConfig = false;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "26.11";
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = import ../../lib/overlays.nix { inherit inputs; };
}
