
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

  {
    "guns/vim-sexp",
    ft = { "lisp", "commonlisp", "scheme" },
    dependencies = { "tpope/vim-sexp-mappings-for-regular-people" },
    init = function()
      vim.g.sexp_enable_insert_mode_mappings = 0
    end,
  },

  {
    "HiPhish/rainbow-delimiters.nvim",
    ft = { "lisp", "commonlisp", "scheme" },
  },
}
