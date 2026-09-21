{ pkgs, inputs, ... }:
{
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];

  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-x86_64-v3;

  services.scx = {
    enable = true;
    package = pkgs.scx.full;
    scheduler = "scx_lavd";
  };
}
