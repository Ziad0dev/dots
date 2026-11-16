local function venv_python()
  local venv = vim.env.VIRTUAL_ENV or vim.env.CONDA_PREFIX
  if venv and vim.fn.executable(venv .. "/bin/python") == 1 then
    return venv .. "/bin/python"
  end
  for _, dir in ipairs({ ".venv", "venv" }) do
    local py = vim.fn.getcwd() .. "/" .. dir .. "/bin/python"
    if vim.fn.executable(py) == 1 then return py end
  end
  return vim.fn.exepath("python3") ~= "" and vim.fn.exepath("python3") or "python"
end

local function pick_program()
  local guess = vim.fn.getcwd() .. "/"
  if vim.uv.fs_stat("zig-out/bin") then
    guess = guess .. "zig-out/bin/"
  elseif vim.uv.fs_stat("target/debug") then
    guess = guess .. "target/debug/"
  elseif vim.uv.fs_stat("build") then
    guess = guess .. "build/"
  end
  return vim.fn.input("Executable: ", guess, "file")
end

local function pick_args()
  local raw = vim.fn.input("Args: ")
  return raw == "" and {} or vim.split(raw, " +", { trimempty = true })
end

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        opts = {},
      },
      { "theHamsta/nvim-dap-virtual-text", opts = { virt_text_pos = "eol" } },
    },
    keys = {
      { "<F5>", function() require("dap").continue() end, desc = "Debug: continue / start" },
      { "<S-F5>", function() require("dap").terminate() end, desc = "Debug: terminate" },
      { "<F9>", function() require("dap").toggle_breakpoint() end, desc = "Debug: toggle breakpoint" },
      { "<F10>", function() require("dap").step_over() end, desc = "Debug: step over" },
      { "<F11>", function() require("dap").step_into() end, desc = "Debug: step into" },
      { "<S-F11>", function() require("dap").step_out() end, desc = "Debug: step out" },
      { "<leader>Db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      {
        "<leader>DB",
        function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end,
        desc = "Conditional breakpoint",
      },
      {
        "<leader>DL",
        function() require("dap").set_breakpoint(nil, nil, vim.fn.input("Log message: ")) end,
        desc = "Logpoint",
      },
      { "<leader>Dc", function() require("dap").continue() end, desc = "Continue / start" },
      { "<leader>DC", function() require("dap").run_to_cursor() end, desc = "Run to cursor" },
      { "<leader>Dl", function() require("dap").run_last() end, desc = "Run last" },
      { "<leader>Dr", function() require("dap").repl.toggle() end, desc = "REPL" },
      { "<leader>Dx", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>Dk", function() require("dap").up() end, desc = "Frame up" },
      { "<leader>Dj", function() require("dap").down() end, desc = "Frame down" },
      { "<leader>Du", function() require("dapui").toggle() end, desc = "Toggle UI" },
      { "<leader>De", function() require("dapui").eval() end, mode = { "n", "v" }, desc = "Eval" },
      { "<leader>DX", function() require("dap").clear_breakpoints() end, desc = "Clear breakpoints" },
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")

      vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })
      local signs = {
        DapBreakpoint = { "", "DiagnosticError" },
        DapBreakpointCondition = { "", "DiagnosticWarn" },
        DapLogPoint = { "", "DiagnosticInfo" },
        DapBreakpointRejected = { "", "DiagnosticHint" },
        DapStopped = { "", "DiagnosticOk", "DapStoppedLine" },
      }
      for name, s in pairs(signs) do
        vim.fn.sign_define(name, { text = s[1], texthl = s[2], linehl = s[3], numhl = "" })
      end

      dap.listeners.after.event_initialized.dapui = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui = function() dapui.close() end
      dap.listeners.before.event_exited.dapui = function() dapui.close() end

      if vim.fn.executable("lldb-dap") == 1 then
        dap.adapters.lldb = { type = "executable", command = "lldb-dap", name = "lldb" }
        local native = {
          {
            name = "Launch",
            type = "lldb",
            request = "launch",
            program = pick_program,
            args = pick_args,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
          },
          {
            name = "Attach to process",
            type = "lldb",
            request = "attach",
            pid = function() return require("dap.utils").pick_process() end,
          },
        }
        for _, ft in ipairs({ "c", "cpp", "rust", "zig" }) do
          dap.configurations[ft] = native
        end
      end

      if vim.fn.executable("elixir-debug-adapter") == 1 then
        dap.adapters.mix_task = { type = "executable", command = "elixir-debug-adapter" }
        dap.configurations.elixir = {
          {
            name = "mix test",
            type = "mix_task",
            request = "launch",
            task = "test",
            taskArgs = { "--trace" },
            startApps = true,
            projectDir = "${workspaceFolder}",
            requireFiles = { "test/**/test_helper.exs", "test/**/*_test.exs" },
          },
          {
            name = "mix run",
            type = "mix_task",
            request = "launch",
            task = "run",
            projectDir = "${workspaceFolder}",
          },
        }
      end

      if vim.fn.executable("debugpy-adapter") == 1 then
        dap.adapters.python = function(cb, config)
          if config.request == "attach" then
            local c = config.connect or {}
            cb({ type = "server", host = c.host or "127.0.0.1", port = c.port or 5678 })
          else
            cb({ type = "executable", command = "debugpy-adapter" })
          end
        end
        dap.adapters.debugpy = dap.adapters.python
        dap.configurations.python = {
          {
            name = "Launch file",
            type = "python",
            request = "launch",
            program = "${file}",
            cwd = "${workspaceFolder}",
            console = "integratedTerminal",
            justMyCode = true,
            pythonPath = venv_python,
          },
          {
            name = "Launch file with args",
            type = "python",
            request = "launch",
            program = "${file}",
            args = pick_args,
            cwd = "${workspaceFolder}",
            console = "integratedTerminal",
            pythonPath = venv_python,
          },
          {
            name = "Launch module",
            type = "python",
            request = "launch",
            module = function() return vim.fn.input("Module: ") end,
            cwd = "${workspaceFolder}",
            console = "integratedTerminal",
            pythonPath = venv_python,
          },
          {
            name = "pytest: current file",
            type = "python",
            request = "launch",
            module = "pytest",
            args = { "${file}", "-q" },
            cwd = "${workspaceFolder}",
            console = "integratedTerminal",
            justMyCode = false,
            pythonPath = venv_python,
          },
          {
            name = "Attach (localhost:5678)",
            type = "python",
            request = "attach",
            connect = { host = "127.0.0.1", port = 5678 },
          },
        }
      end
    end,
  },
}
