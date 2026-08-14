{
  description = "Elixir devshell — OTP-matched, same pattern as the system setup";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      beam = pkgs.beam.packages.erlang_27;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          beam.erlang
          beam.elixir
          beam.elixir-ls
        ];
      };
    };
}
