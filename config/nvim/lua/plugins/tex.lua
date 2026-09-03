
return {
  {
    "lervag/vimtex",

    lazy = false,
    init = function()
      vim.g.vimtex_mappings_disable = { n = { "K" } }
      vim.g.vimtex_view_method = "zathura"
      vim.g.vimtex_view_automatic = 1
      vim.g.vimtex_view_forward_search_on_start = 1

      vim.g.vimtex_compiler_method = "latexmk"
      vim.g.vimtex_compiler_latexmk = {
        aux_dir = "build",
        out_dir = "build",
        callback = 1,
        continuous = 1,
        executable = "latexmk",
        hooks = {},
        options = {
          "-verbose",
          "-file-line-error",
          "-synctex=1",
          "-interaction=nonstopmode",
        },
      }

      vim.g.vimtex_quickfix_mode = 0
      vim.g.vimtex_quickfix_open_on_warning = 0

      vim.g.vimtex_mappings_prefix = "<localleader>l"
      vim.g.vimtex_syntax_enabled = 1
      vim.g.vimtex_indent_enabled = 1

      vim.g.vimtex_syntax_conceal = {
        accents = 1,
        greek = 1,
        math_bounds = 0,
        math_delimiters = 1,
        math_super_sub = 1,
        math_symbols = 1,
        styles = 1,
      }
    end,
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("reaper_tex", { clear = true }),
        pattern = { "tex", "plaintex" },
        callback = function(ev)
          vim.opt_local.conceallevel = 2
          vim.opt_local.spell = true
          vim.opt_local.wrap = true
          vim.opt_local.linebreak = true
          local function m(keys, fn, desc)
            vim.keymap.set("n", keys, fn, { buffer = ev.buf, desc = "TeX: " .. desc })
          end
          m("<leader>dc", "<cmd>VimtexCompile<cr>", "Toggle continuous compile")
          m("<leader>dv", "<cmd>VimtexView<cr>", "Forward search to zathura")
          m("<leader>ds", "<cmd>VimtexStop<cr>", "Stop compiler")
          m("<leader>dx", "<cmd>VimtexClean<cr>", "Clean aux files")
          m("<leader>de", "<cmd>VimtexErrors<cr>", "Errors")
        end,
      })
    end,
  },
}
