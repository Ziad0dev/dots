{ ... }:

# MangoHud, declaratively. Toggle in-game with Shift_R+F12 — starts hidden
# so it doesn't sit over everything by default. Gamescope's --mangoapp
# reads the same config.

{
  programs.mangohud = {
    enable = true;
    settings = {
      position = "top-left";
      toggle_hud = "Shift_R+F12";
      no_display = true; # hidden until toggled
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
}
