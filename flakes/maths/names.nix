{
  core = [
    "z3"
    "graphviz"
    "gnuplot"
    "pandoc"
  ];

  lean = [
    "elan"
    "lean4"
    "gmp"
    "cadical"
  ];

  coq = [
    "coq"
    "coqPackages.coq-lsp"
    "coqPackages.mathcomp"
    "coqPackages.stdpp"
    "rocq-core"
  ];

  agda = [
    "agda"
    "agdaPackages.standard-library"
  ];

  isabelle = [
    "isabelle"
  ];

  smt = [
    "z3"
    "cvc5"
    "alt-ergo"
    "why3"
    "vampire"
    "eprover"
    "tlaplus"
  ];

  cas = [
    "sage"
    "pari"
    "gp2c"
    "gap"
    "singular"
    "macaulay2"
    "maxima"
    "wxmaxima"
    "octave"
    "gmp"
    "mpfr"
    "flint"
    "ntl"
  ];

  typeset = [
    "typst"
    "tectonic"
    "pandoc"
    "texliveMedium"
  ];

  viz = [
    "inkscape"
    "geogebra"
    "graphviz"
    "gnuplot"
    "python3Packages.manim"
  ];

  julia = [
    "julia-bin"
  ];

  python = [ ];
}
