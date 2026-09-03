return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function m(keys, fn, desc, mode)
          vim.keymap.set(mode or "n", keys, fn, { buffer = bufnr, desc = "Git: " .. desc })
        end
        m("]h", function() gs.nav_hunk("next") end, "Next hunk")
        m("[h", function() gs.nav_hunk("prev") end, "Prev hunk")
        m("<leader>hs", gs.stage_hunk, "Stage hunk")
        m("<leader>hr", gs.reset_hunk, "Reset hunk")
        m("<leader>hs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage selection", "v")
        m("<leader>hr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset selection", "v")
        m("<leader>hp", gs.preview_hunk, "Preview hunk")
        m("<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
        m("<leader>hd", gs.diffthis, "Diff this")
        m("<leader>hB", gs.toggle_current_line_blame, "Toggle inline blame")
      end,
    },
  },

  {
    "tpope/vim-fugitive",
    cmd = { "Git", "G", "Gdiffsplit", "Gblame" },
    keys = {
      { "<leader>gs", "<cmd>Git<cr>", desc = "Git status (fugitive)" },
    },
  },
}
