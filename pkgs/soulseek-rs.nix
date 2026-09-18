{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

let
  version = "19.0.0";
in
rustPlatform.buildRustPackage {
  pname = "soulseek-rs";
  inherit version;

  src = fetchFromGitHub {
    owner = "michel";
    repo = "soulseek-rs";
    tag = "v${version}";
    hash = "sha256-L9NryE0dfKxXmbGBWeS2xFvj/QfcFpl1HuQvo/6QrIc=";
  };

  cargoHash = "sha256-P1RJ6E71o8+K9o3hvgCLZ4h57Qtlgh7cXqzyUcKyt5A=";
  cargoBuildFlags = [
    "-p"
    "soulseek-rs"
  ];

  meta = {
    description = "Terminal client for the Soulseek network";
    homepage = "https://github.com/michel/soulseek-rs";
    license = lib.licenses.mit;
    mainProgram = "soulseek-rs";
    platforms = lib.platforms.unix;
  };
}
