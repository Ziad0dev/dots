{
  config,
  lib,
  pkgs,
  ...
}:
let
  dots = config.dots.repoPath;
in
{
  home.packages = with pkgs; [
    deadnix
    statix
  ];

  # scripts/git-hooks/ has always been in the repo but nothing pointed git at
  # it, so the pre-commit checks never ran on a single commit.
  home.activation.dotsGitHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "${dots}/.git" ]; then
      run ${pkgs.git}/bin/git -C "${dots}" config core.hooksPath scripts/git-hooks
      run chmod +x "${dots}"/scripts/git-hooks/* 2>/dev/null || true
    fi
  '';
}
