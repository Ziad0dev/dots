{ inputs, ... }:

let
  # Each app is pinned to a commit, so a switch installs exactly that build.
  # To bump one: `flatpak remote-info --user --log <origin> <appId>`, pick a
  # commit, paste it here. Runtimes follow whatever the pinned app requires.
  pinned = origin: appId: commit: { inherit origin appId commit; };
in
{
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

  services.flatpak = {
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
      {
        name = "GeForceNOW";
        location = "https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow.flatpakrepo";
      }
    ];

    packages = [
      (pinned "GeForceNOW" "com.nvidia.geforcenow"
        "f04023919e48360fa55cc550f79b1041c1725680d30414e5bda9fd73ef26d324"
      )
      (pinned "flathub" "com.github.johnfactotum.Foliate"
        "4ca532b545422340d60651e8d4a912192dade5dc6f0af264f051215c5e6f489c"
      )
      (pinned "flathub" "com.github.tchx84.Flatseal"
        "ef9fe38e9cb96c170ea579fe1bbf8c76011255d4962d7fc4b3aa4e0a6063f8ae"
      )
      (pinned "flathub" "com.usebottles.bottles"
        "b63354d6e95377f11796244da517df58866c708aeab2b13cf81082ba5a14c1dd"
      )
      (pinned "flathub" "io.github.f3d_app.f3d"
        "4cb78c2d63744ccb2b0e2fee311271bea6deb6ef1cc8df50088500ee5cdc44cd"
      )
      (pinned "flathub" "net.meshlab.MeshLab"
        "7dad24785bc8010251e8cb86d1c94818da5172549de272fad2fa34f89918e987"
      )
      (pinned "flathub" "org.blender.Blender"
        "f97247d9e87dca0bc28c6a01e51cd6425cf8b21c636d28514898b7315b21d521"
      )
      (pinned "flathub" "org.gnome.SimpleScan"
        "03a3320a68af5423ec6e18967906f8e7942057e159f554ced7e5d065c18b0d75"
      )
      (pinned "flathub" "org.kde.kdenlive"
        "32a1f8dceb188a93aa42e58d55cf4cd100ddcfa14a0e11ce0db6eb9dd61b9a2a"
      )
      (pinned "flathub" "org.texstudio.TeXstudio"
        "e93228a667a4f56e53718e4794073b62dac1268206c6830d95a91af62644a078"
      )
    ];

    # anything installed by hand is removed on the next switch, as before
    uninstallUnmanaged = true;

    overrides.settings."com.nvidia.geforcenow".Environment.SDL_VIDEODRIVER = "x11";
  };
}
