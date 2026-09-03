return {
  {
    "folke/snacks.nvim",
    priority = 900,
    lazy = false,
    opts = {
      bigfile = { enabled = true },
      quickfile = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true, timeout = 2500 },
      scroll = { enabled = true },
      words = { enabled = true },
      indent = {
        enabled = true,
        indent = { char = "│" },
        scope = { char = "│" },
      },
      picker = {
        enabled = true,
        ui_select = true,
        layout = { preset = "telescope" },
        sources = {
          explorer = {
            layout = { preset = "sidebar", preview = false },
            hidden = true,
            ignored = false,
            auto_close = false,
            win = {
              list = {
                keys = {
                  ["<c-t>"] = "tab",
                  ["h"] = "explorer_close",
                  ["l"] = "confirm",
                  ["."] = "explorer_focus",
                  ["<BS>"] = "explorer_up",
                },
              },
            },
          },
        },
      },
      explorer = { enabled = true, replace_netrw = false },
      terminal = {
        win = { style = "terminal", border = "rounded" },
      },
      zen = {
        toggles = { dim = true },
        win = { width = 100 },
      },
      dashboard = {
        width = 18,
        preset = {
          keys = {
            { icon = "", key = "f", desc = " ̲find file", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = "", key = "n", desc = " ̲new file", action = ":ene | startinsert" },
            { icon = "", key = "g", desc = " ̲grep text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = "", key = "r", desc = " ̲recent file", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = "", key = "c", desc = " ̲config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = "", key = "s", desc = " ̲session", section = "session" },
            { icon = "", key = "L", desc = " ̲Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            { icon = "", key = "q", desc = " ̲quit", action = ":qa" },
          },
          header = require("config.theme").art(),
        },
        formats = {
          key = function(item)
            return {
              { item.key, hl = "SnacksDashboardKey" },
              { " " },
              { item.desc, hl = "SnacksDashboardDesc" },
            }
          end,
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 0, padding = 1 },
          { section = "startup" },
        },
      },
    },
    keys = {
      { "<leader>e", function() Snacks.explorer() end, desc = "Explorer" },
      { "<C-n>", function() Snacks.explorer() end, desc = "Explorer" },
      { "<leader>fe", function() Snacks.explorer.reveal() end, desc = "Reveal file in explorer" },

      { "<leader>ff", function() Snacks.picker.files() end, desc = "Find files" },
      { "<leader>fg", function() Snacks.picker.grep() end, desc = "Live grep" },
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>fh", function() Snacks.picker.help() end, desc = "Help tags" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent files" },
      { "<leader>fd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      { "<leader>fk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
      { "<leader>fs", function() Snacks.picker.lsp_symbols() end, desc = "Document symbols" },
      { "<leader>fS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "Workspace symbols" },
      { "<leader>fu", function() Snacks.picker.undo() end, desc = "Undo tree" },
      { "<leader>f/", function() Snacks.picker.lines() end, desc = "Search buffer" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Config files" },
      { "<leader>fR", function() Snacks.picker.resume() end, desc = "Resume last picker" },

      { "<leader>gg", function() Snacks.lazygit() end, desc = "LazyGit" },
      { "<leader>gl", function() Snacks.lazygit.log() end, desc = "LazyGit log" },
      { "<leader>gB", function() Snacks.gitbrowse() end, desc = "Open in browser" },

      { "<leader>tt", function() Snacks.terminal() end, desc = "Terminal (float)" },
      { "<C-\\>", function() Snacks.terminal() end, mode = { "n", "t" }, desc = "Toggle terminal" },
      { "<leader>tz", function() Snacks.zen() end, desc = "Zen mode" },
      { "<leader>tZ", function() Snacks.zen.zoom() end, desc = "Zoom window" },
      { "<leader>.", function() Snacks.scratch() end, desc = "Scratch buffer" },
      { "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete buffer" },
      { "<leader>rf", function() Snacks.rename.rename_file() end, desc = "Rename file" },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss notifications" },

      { "]]", function() Snacks.words.jump(1, true) end, mode = { "n", "t" }, desc = "Next reference" },
      { "[[", function() Snacks.words.jump(-1, true) end, mode = { "n", "t" }, desc = "Prev reference" },
    },
  },
}
