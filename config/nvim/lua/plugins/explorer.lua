local function pick_folder()
  local cmd = vim.fn.executable("fd") == 1
      and { "fd", "--type", "d", "--hidden", "--max-depth", "6", "--exclude", ".git" }
    or { "find", ".", "-type", "d", "-not", "-path", "*/.git/*" }

  local dirs = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 or #dirs == 0 then
    vim.notify("no directories found", vim.log.levels.WARN)
    return
  end
  table.insert(dirs, 1, ".")

  vim.ui.select(dirs, { prompt = "Open folder as root:" }, function(choice)
    if not choice then return end
    local path = vim.fn.fnamemodify(choice, ":p")
    vim.cmd.tcd(vim.fn.fnameescape(path))
    local ok, snacks = pcall(require, "snacks")
    if ok then
      snacks.explorer({ cwd = path })
    else
      vim.cmd.edit(vim.fn.fnameescape(path))
    end
  end)
end

return {
  {
    "stevearc/oil.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      default_file_explorer = true,
      delete_to_trash = true,
      skip_confirm_for_simple_edits = true,
      watch_for_changes = true,
      view_options = { show_hidden = true },
      float = { padding = 4, max_width = 120, max_height = 32, border = "rounded" },
      keymaps = {
        ["q"] = "actions.close",
        ["<C-h>"] = false,
        ["<C-l>"] = false,
        ["<C-s>"] = false,
        ["`"] = "actions.cd",
        ["~"] = "actions.tcd",
        ["gy"] = "actions.copy_entry_path",
      },
    },
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
      { "<leader>-", function() require("oil").open_float() end, desc = "Parent directory (float)" },
    },
  },

  {
    "mikavilpas/yazi.nvim",
    cmd = "Yazi",
    keys = {
      { "<leader>y", "<cmd>Yazi<cr>", desc = "Yazi at current file" },
      { "<leader>Y", "<cmd>Yazi cwd<cr>", desc = "Yazi in cwd" },
      { "<leader>yr", "<cmd>Yazi toggle<cr>", desc = "Resume last yazi" },
    },
    opts = {
      open_for_directories = false,
      keymaps = { show_help = "<f1>" },
    },
  },

  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>fp", pick_folder, desc = "Open folder as root" },
      { "<leader>fF", function() Snacks.explorer({ cwd = vim.fn.expand("%:p:h") }) end, desc = "Explorer at file's folder" },
    },
  },
}
