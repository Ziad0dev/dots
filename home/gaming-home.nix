{ lib, ... }:

{
  programs.mangohud = {
    enable = true;
    settings = {
      position = "top-left";
      toggle_hud = "Shift_R+F12";
      no_display = true;
      fps = true;
      frametime = true;
      frame_timing = true;
      gpu_stats = true;
      gpu_temp = true;
      cpu_stats = true;
      cpu_temp = true;
      ram = true;
      vram = true;
    };
  };

  home.activation.gfnSdlOverride = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v flatpak >/dev/null 2>&1 \
      && flatpak info com.nvidia.geforcenow >/dev/null 2>&1; then
      run flatpak override --user --env=SDL_VIDEODRIVER=x11 com.nvidia.geforcenow || true
    fi
  '';
}
