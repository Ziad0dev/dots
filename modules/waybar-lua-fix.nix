{ config, lib, pkgs, ... }:

# TEMPORARY — delete this file (and its flake.nix entry) once nixpkgs ships
# a waybar release newer than 0.15.0.
#
# waybar 0.15.0 sends legacy "dispatch workspace N" IPC strings, which
# Hyprland's Lua dispatcher can't parse (Waybar #5008) — workspace clicks
# do nothing. Master is fixed: IPC::dispatch detects the Lua protocol and
# builds hl.dsp-form dispatches. So: same package expression, master source.

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

        # Master added a WWAN (cellular modem) module needing mm-glib from
        # ModemManager, which 0.15.0's expression doesn't carry. nixpkgs
        # passes -Dauto_features=enabled, so meson tries to build it and
        # hard-fails. An explicit feature value overrides auto_features.
        # Desktop with no modem → disable. (Alternative, if you ever want
        # the module: drop this flag and add `modemmanager` to buildInputs.)
        # Second master-vs-0.15.0 gap: master wants libcava >= 1.0.0, nixpkgs
        # ships 0.10.7. nixpkgs passes -Dcava=enabled, so meson treats it as
        # mandatory and falls back to downloading a wrap subproject, which the
        # sandbox blocks. Filter that flag out and disable the module — the
        # waybar config here has no cava (audio visualizer) module anyway.
        mesonFlags =
          (lib.filter (f: f != "-Dcava=enabled") (old.mesonFlags or [ ]))
          ++ [ "-Dwwan=disabled" "-Dcava=disabled" ];

        # versionCheckHook runs `waybar --version` and expects it to contain
        # `version` above. The binary reports meson's project version
        # (0.15.0), so the "-lua-ipc-fix" suffix would fail the check. The
        # suffix is worth keeping — it's how this shows up in nh's generation
        # diff — so skip the check instead.
        doInstallCheck = false;
      });
    })
  ];
}
