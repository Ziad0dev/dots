-- ⸸ HAIL SATAN - Pywal Colors ⸸

return {
  -- TokyoNight theme (backup only)
  {
    "folke/tokyonight.nvim",
    lazy = true,
    priority = 900,
    opts = function()
      return {
        style = "night", -- night, storm, day, moon
        transparent = false,
        terminal_colors = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true, bold = true },
          sidebars = "dark", 
          floats = "dark",
        },
        sidebars = { "qf", "help" },
        day_brightness = 0.3,
        hide_inactive_statusline = false,
        dim_inactive = false,
        lualine_bold = false,
        
        -- Custom satanic color overrides
        on_colors = function(colors)
          -- Hell red accents
          colors.red = "#cc0000"
          colors.red1 = "#ff0000"
          colors.orange = "#ff4500"
          
          -- Darker background for more satanic feel
          colors.bg = "#0a0a0a"
          colors.bg_dark = "#000000"
          colors.bg_float = "#0d0d0d"
          colors.bg_highlight = "#1a1a1a"
          colors.bg_popup = "#0d0d0d"
          colors.bg_search = "#660000"
          colors.bg_sidebar = "#050505"
          colors.bg_statusline = "#0a0a0a"
          colors.bg_visual = "#330000"
          
          -- Blood red for selection
          colors.purple = "#cc0066"
          colors.magenta = "#ff0066"
        end,
        
        on_highlights = function(hl, c)
          -- Satanic cursor line
          hl.CursorLine = { bg = c.bg_highlight }
          hl.CursorLineNr = { fg = c.red, bold = true }
          
          -- Diabolic line numbers
          hl.LineNr = { fg = "#666666" }
          
          -- Hell search highlighting
          hl.Search = { bg = c.bg_search, fg = c.fg }
          hl.IncSearch = { bg = c.red, fg = c.bg }
          
          -- Satanic visual selection
          hl.Visual = { bg = c.bg_visual }
          
          -- Evil error colors
          hl.DiagnosticError = { fg = c.red1 }
          hl.DiagnosticWarn = { fg = c.orange }
          
          -- Demonic completion menu
          hl.Pmenu = { fg = c.fg, bg = c.bg_popup }
          hl.PmenuSel = { fg = c.bg, bg = c.red }
          hl.PmenuSbar = { bg = c.bg_popup }
          hl.PmenuThumb = { bg = c.red }
        end,
      }
    end,
    config = function(_, opts)
      require("tokyonight").setup(opts)
      -- Don't auto-set - pywal will handle colorscheme
    end,
  },

  -- Alternative: Catppuccin (also excellent)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    enabled = false, -- Set to true if you prefer catppuccin
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha", -- latte, frappe, macchiato, mocha
      background = {
        light = "latte",
        dark = "mocha",
      },
      transparent_background = false,
      show_end_of_buffer = false,
      term_colors = true,
      compile_enable = true,
      compile_path = vim.fn.stdpath("cache") .. "/catppuccin",
      
      -- Satanic customizations
      custom_highlights = function(colors)
        return {
          CursorLine = { bg = colors.surface0 },
          CursorLineNr = { fg = colors.red, style = { "bold" } },
          LineNr = { fg = colors.overlay0 },
          Visual = { bg = colors.surface1 },
          Search = { bg = colors.red, fg = colors.base },
          IncSearch = { bg = colors.peach, fg = colors.base },
        }
      end,
      
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        telescope = true,
        which_key = true,
        mason = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
        },
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      -- vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },
} 