{
  description = "C/C++ — clang + clangd + mold, compile_commands.json wired";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgs.mkShell.override {

        stdenv = pkgs.clangStdenv;
      } {
        packages = with pkgs; [
          clang-tools
          mold
          bear
          meson ninja cmake
          gdb lldb
          valgrind
          pkg-config
        ];

        NIX_CFLAGS_LINK = "-fuse-ld=mold";

        shellHook = ''
          echo "C/C++ shell — clang $(clang --version | head -1 | grep -o '[0-9.]*' | head -1), mold linked"
          echo "  bear -- make    regenerate compile_commands.json for clangd"
        '';
      };
    };
}
