{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    libplacebo
  ];

  environment.sessionVariables = {
    DXVK_HDR = "1";
    PROTON_ENABLE_WAYLAND = "1";
    PROTON_ENABLE_HDR = "1";
  };

}
