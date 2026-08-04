-- ============================================================================
-- Common Lisp — interactive development via nvlime (Neovim fork of vlime).
--
-- There is no good Common Lisp LSP; the language's development model is a live
-- image you talk to, not a static analysis server. nvlime wraps a Swank server
-- and gives you eval-in-place, the inspector, the debugger, and cross-reference
-- — the actual reason to write Lisp.
--
-- Requires: sbcl with swank. dev-langs.nix provides this declaratively via
-- sbcl.withPackages, so there is no first-run install step — <localleader>cc
-- connects straight away.
-- ============================================================================

return {
  {
    "monkoose/nvlime",
    ft = { "lisp", "commonlisp" },
    dependencies = { "monkoose/parsley" },
    init = function()
      vim.g.nvlime_config = {
        leader = "<localleader>",
        implementation = "sbcl",
      }
    end,
  },

  -- Structural editing. Without this you are typing parens by hand like an
  -- animal. vim-sexp gives you slurp/barf/wrap on s-expressions; the mappings
  -- plugin makes them memorable instead of chorded nonsense.
  {
    "guns/vim-sexp",
    ft = { "lisp", "commonlisp", "scheme" },
    dependencies = { "tpope/vim-sexp-mappings-for-regular-people" },
    init = function()
      vim.g.sexp_enable_insert_mode_mappings = 0 -- don't fight your own typing
    end,
  },

  -- Rainbow parens: the cheapest possible depth cue.
  {
    "HiPhish/rainbow-delimiters.nvim",
    ft = { "lisp", "commonlisp", "scheme" },
  },
}
