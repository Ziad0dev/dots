(import ../lib/toolkit.nix).mkModule {
  name = "infosec";
  description = "curated infosec toolkit";
  packages = ./packages.nix;
}
