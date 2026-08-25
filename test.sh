for t in zig c beam haskell lisp rust python latex; do
  echo "== $t"; nix flake check --all-systems ./templates/$t || echo "FAILED: $t"
done
nix flake check ./templates/typst
