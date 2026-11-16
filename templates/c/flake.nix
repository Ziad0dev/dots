{
  description = "C/C++ — clang + clangd + mold, compile_commands.json wired";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = eachSystem (
        pkgs:
        let
          isLinux = pkgs.stdenv.hostPlatform.isLinux;
        in
        {
          default =
            pkgs.mkShell.override
              {
                stdenv = pkgs.clangStdenv;
              }
              {
                packages =
                  with pkgs;
                  [
                    clang-tools
                    bear
                    meson
                    ninja
                    cmake
                    lldb
                    pkg-config
                  ]
                  ++ pkgs.lib.optionals isLinux [
                    mold
                    gdb
                    valgrind
                  ];

                NIX_CFLAGS_LINK = pkgs.lib.optionalString isLinux "-fuse-ld=mold";

                shellHook = ''
                  echo "C/C++ shell — clang $(clang --version | head -1 | grep -o '[0-9.]*' | head -1)"
                  echo "  bear -- make    regenerate compile_commands.json for clangd"
                '';
              };
        }
      );
    };
}
