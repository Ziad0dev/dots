{ config, lib, pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      waybar = prev.waybar.overrideAttrs (old: {
        version = "0.15.0-lua-ipc-fix";
        src = final.fetchFromGitHub {
          owner = "Alexays";
          repo = "Waybar";
          rev = "30610d3b68f109e950d924bc7d9c42b8cbbc5df8";
          hash = "sha256-pSbVf9mMWazkaTgNM0X4pfkIS/6AzoAfs7YTS27udOE=";
        };

        mesonFlags =
          (lib.filter (f: f != "-Dcava=enabled") (old.mesonFlags or [ ]))
          ++ [ "-Dwwan=disabled" "-Dcava=disabled" ];

        doInstallCheck = false;
      });
    })
  ];
}
