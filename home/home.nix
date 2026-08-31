{
  lib,
  system,
  profile ? "minimal",
  ...
}:

let
  isDarwin = lib.hasSuffix "-darwin" system;
  desktop = profile == "desktop";
in
{
  imports = [
    ./profiles/base.nix
  ]
  ++ lib.optional isDarwin ./profiles/darwin.nix
  ++ lib.optional (!isDarwin && desktop) ./profiles/linux-desktop.nix;
}
