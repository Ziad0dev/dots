{
  description = "Elixir devshell — OTP-matched, same pattern as the system setup";

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
          beam = pkgs.beam.packages.erlang_27;
        in
        {
          default = pkgs.mkShell {
            packages = [
              beam.erlang
              beam.elixir
              beam.elixir-ls
            ];
          };
        }
      );
    };
}
