(import ../lib/toolkit.nix).mkModule {
  name = "maths";
  description = "pure maths toolkit";
  packages = ./packages.nix;
}
