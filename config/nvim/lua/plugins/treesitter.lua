return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({
        install_dir = vim.fn.stdpath("data") .. "/site",
      })

      require("nvim-treesitter").install({
        "lua",
        "vim",
        "vimdoc",
        "query",
        "bash",
        "fish",
        "python",
        "rust",
        "c",
        "cpp",
        "zig",
        "commonlisp",
        "cmake",
        "make",
        "javascript",
        "typescript",
        "tsx",
        "json",
        "jsonc",
        "yaml",
        "toml",
        "nix",
        "latex",
        "typst",
        "markdown",
        "markdown_inline",
        "html",
        "css",
        "scss",
        "svelte",
        "vue",
        "norg",
        "git_config",
        "gitcommit",
        "diff",
        "regex",
        "gitignore",
      })

      vim.opt.foldlevel = 99
      vim.opt.foldlevelstart = 99

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local ft = args.match
          local lang = vim.treesitter.language.get_lang(ft) or ft

          local ok_add = pcall(vim.treesitter.language.add, lang)
          if not ok_add then
            return
          end

          local ok_start = pcall(vim.treesitter.start, args.buf, lang)
          if not ok_start then
            vim.bo[args.buf].syntax = "on"
            return
          end

          vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
          vim.wo[0][0].foldmethod = "expr"

          pcall(function()
            vim.bo[args.buf].indentexpr =
              "v:lua.require'nvim-treesitter'.indentexpr()"
          end)
        end,
      })
    end,
  },
}
