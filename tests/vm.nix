# The vm host booted as a NixOS test: home-manager activates in pure mode and
# renders the default theme. This test uses no private key or SOPS fixture.
# Disk layout and impermanence are left to the ISO install
# (docs/install.md#testing-in-a-vm); here the test driver provides the disks.
#
#   nix build .#checks.x86_64-linux.vm -L
{
  pkgs,
  inputs,
  mk,
  username,
}:

let
  system = "x86_64-linux";
in
pkgs.testers.runNixOSTest {
  name = "dots-vm";

  # the host sets its own overlays and allowUnfree
  node.pkgsReadOnly = false;

  node.specialArgs = {
    inherit inputs username system;
    hostname = "vm";
    profile = "minimal";
  };

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        ../hosts/vm
      ]
      ++ mk.hmNixos {
        inherit username system;
        profile = "minimal";
        homeModule = ../home/home.nix;
      };

      disko.enableConfig = false;
      dots.impermanence.enable = lib.mkForce false;
      virtualisation = {
        memorySize = 3072;
        cores = 2;
        # the minimal profile is big; the store is shared, the image isn't
        diskSize = 4096;
      };
      # the test driver boots the kernel directly
      boot.loader.systemd-boot.enable = lib.mkForce false;
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("nothing failed"):
        machine.succeed("test -z \"$(systemctl --failed --no-legend)\"")

    with subtest("the test account exists"):
        machine.succeed("getent passwd ${username}")

    with subtest("home-manager activates in pure mode"):
        machine.wait_for_unit("home-manager-${username}.service")
        machine.succeed("readlink -f /home/${username}/.config/nvim | grep -q '^/nix/store/.*-source/config/nvim$'")

    with subtest("the default theme is rendered on first activation"):
        machine.succeed("test \"$(cat /home/${username}/.local/state/dots/theme/current)\" = oxocarbon")
        machine.succeed("test -s /home/${username}/.local/state/dots/theme/prompt.fish")
        machine.succeed("readlink -f /home/${username}/.local/state/dots/shell/current/theme/colors.sh | grep -q '^/nix/store/'")
  '';
}
