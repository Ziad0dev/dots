{ pkgs, ... }:

let
  debugpyAdapter = pkgs.writeShellScriptBin "debugpy-adapter" ''
    exec ${pkgs.python3.withPackages (ps: [ ps.debugpy ])}/bin/python -m debugpy.adapter "$@"
  '';
in
{
  home.packages = with pkgs; [
    bash-language-server
    taplo
    vscode-langservers-extracted
    yaml-language-server
    marksman
    typescript-language-server
    stylua
    shfmt
    prettier
    debugpyAdapter
  ];
}
