{ pkgs, ... }:

# ── HDR ───────────────────────────────────────────────────────────────────────
# Output-side HDR for the DP-1 OLED (XG27AQDMG). The compositor half lives in
# config/hypr/hyprland.lua; this module owns the app/env side.
#
# DRIVER NOTE: configuration.nix pins nvidiaPackages.latest, which resolves to
# 610.43.03 on the locked nixpkgs. NVIDIA implements the Vulkan HDR WSI
# extensions natively from 595.58.03 onward, so vk_hdr_layer and
# ENABLE_HDR_WSI=1 are NOT needed and must not be set. (vk_hdr_layer was also
# dropped from nixpkgs, so there is nothing to install regardless.)

{
  environment.systemPackages = with pkgs; [
    libplacebo   # tone-mapping backend behind mpv's gpu-next
  ];

  # Proton/Wine HDR path. Inert on SDR surfaces and for titles without HDR
  # support, so session-wide is safe; override per-title in Steam launch
  # options if a specific game misbehaves.
  #
  #   DXVK_HDR              — DXVK advertises HDR swapchains to D3D11/12
  #   PROTON_ENABLE_WAYLAND — Proton's native Wayland driver. REQUIRED: the
  #                           XWayland path cannot carry HDR metadata at all.
  #   PROTON_ENABLE_HDR     — arms HDR once the Wayland driver is live
  environment.sessionVariables = {
    DXVK_HDR = "1";
    PROTON_ENABLE_WAYLAND = "1";
    PROTON_ENABLE_HDR = "1";
  };

  # Gamescope HDR (--hdr-enabled) is deliberately NOT wired here: it has known
  # critical issues on NVIDIA. gaming.nix already provides the gamescope
  # session; test the plain Proton-Wayland path above first.
}
