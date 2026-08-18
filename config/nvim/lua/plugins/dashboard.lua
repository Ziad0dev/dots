return {
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      -- Art lives in plain .txt files under nvim/art/ rather than inline Lua.
      -- Keeps this file readable and means the art needs no escaping — ^, ~,
      -- backslashes and quotes all pass through untouched.
      local function read_art(name)
        local path = vim.fn.stdpath("config") .. "/art/" .. name .. ".txt"
        local fh = io.open(path, "r")
        if not fh then
          return nil
        end
        local lines = {}
        for line in fh:lines() do
          table.insert(lines, line)
        end
        fh:close()
        return #lines > 0 and lines or nil
      end

      local banner = {
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

      -- The big piece is 74 rows tall; buttons + footer + padding need ~20
      -- more. In a shorter window alpha would push the buttons off screen, so
      -- fall back to the compact banner instead of rendering something broken.
      local function pick_header()
        local art = read_art("severance")
        if art and vim.o.lines >= (#art + 20) then
          return art
        end
        return banner
      end

      dashboard.section.header.val = pick_header()

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

      -- Re-pick on resize: going fullscreen should get the big art, and
      -- shrinking should drop back to the banner rather than clipping.
      vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
          if vim.bo.filetype == "alpha" then
            dashboard.section.header.val = pick_header()
            pcall(vim.cmd.AlphaRedraw)
          end
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimStarted",
        callback = function()
          pcall(vim.cmd.AlphaRedraw)
        end,
      })
    end,
  },
}
