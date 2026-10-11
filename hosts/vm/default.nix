# A small NixOS host for testing the dots end to end: the installer ISO puts
# it on a blank disk (disko), root is a tmpfs (impermanence), and
# home-manager runs the minimal profile with config/ copied into the store
# (liveConfig = false). The console auto-logs in for tests; it has no account
# password and uses no SOPS data.
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

  programs.fish.enable = true;
  programs.fish.interactiveShellInit = ''
    printf '%s\n' DOTS_VM_AUTOLOGIN_READY
  '';
  services.getty.autologinUser = username;
  services.openssh.enable = lib.mkForce false;
  users.allowNoPasswordLogin = true;
  security.sudo.wheelNeedsPassword = false;

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = config.programs.fish.package;
    hashedPassword = "!";
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
