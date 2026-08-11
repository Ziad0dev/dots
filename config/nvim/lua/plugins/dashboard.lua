
return {
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        [[                                                ]],
        [[              ⸸   H A I L   ☠   ⸸               ]],
        [[                                                ]],
        [[██████╗ ███████╗ █████╗ ██████╗ ███████╗██████╗ ]],
        [[██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗]],
        [[██████╔╝█████╗  ███████║██████╔╝█████╗  ██████╔╝]],
        [[██╔══██╗██╔══╝  ██╔══██║██╔═══╝ ██╔══╝  ██╔══██╗]],
        [[██║  ██║███████╗██║  ██║██║     ███████╗██║  ██║]],
        [[╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝]],
      }

      dashboard.section.buttons.val = {
        dashboard.button("f", "  Find file", "<cmd>Telescope find_files<cr>"),
        dashboard.button("r", "  Recent files", "<cmd>Telescope oldfiles<cr>"),
        dashboard.button("g", "  Live grep", "<cmd>Telescope live_grep<cr>"),
        dashboard.button("n", "  New file", "<cmd>ene <bar> startinsert<cr>"),
        dashboard.button("e", "  File explorer", "<cmd>Neotree toggle<cr>"),
        dashboard.button("c", "  Config", "<cmd>e $MYVIMRC<cr>"),
        dashboard.button("l", "  Lazy", "<cmd>Lazy<cr>"),
        dashboard.button("q", "  Quit", "<cmd>qa<cr>"),
      }

      dashboard.section.header.opts.hl = "Function"
      for _, b in ipairs(dashboard.section.buttons.val) do
        b.opts.hl = "Keyword"
        b.opts.hl_shortcut = "Constant"
      end

      dashboard.section.footer.val = function()
        local stats = require("lazy").stats()
        local ms = math.floor(stats.startuptime * 100 + 0.5) / 100
        return "⸸ " .. stats.loaded .. "/" .. stats.count .. " plugins in " .. ms .. "ms ⸸"
      end
      dashboard.section.footer.opts.hl = "Comment"

      dashboard.config.opts.noautocmd = true
      alpha.setup(dashboard.config)

      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimStarted",
        callback = function()
          pcall(vim.cmd.AlphaRedraw)
        end,
      })
    end,
  },
}
