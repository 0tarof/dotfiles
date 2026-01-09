return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "nvim-neotest/nvim-nio",
    "theHamsta/nvim-dap-virtual-text",
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    -- Setup DAP UI
    dapui.setup({
      icons = { expanded = "", collapsed = "", current_frame = "" },
      mappings = {
        expand = { "<CR>", "<2-LeftMouse>" },
        open = "o",
        remove = "d",
        edit = "e",
        repl = "r",
        toggle = "t",
      },
      layouts = {
        {
          elements = {
            { id = "scopes", size = 0.25 },
            { id = "breakpoints", size = 0.25 },
            { id = "stacks", size = 0.25 },
            { id = "watches", size = 0.25 },
          },
          size = 40,
          position = "left",
        },
        {
          elements = {
            { id = "repl", size = 0.5 },
            { id = "console", size = 0.5 },
          },
          size = 10,
          position = "bottom",
        },
      },
      floating = {
        max_height = nil,
        max_width = nil,
        border = "rounded",
        mappings = {
          close = { "q", "<Esc>" },
        },
      },
    })

    -- Setup virtual text
    require("nvim-dap-virtual-text").setup({
      enabled = true,
      enabled_commands = true,
      highlight_changed_variables = true,
      highlight_new_as_changed = false,
      show_stop_reason = true,
      commented = false,
      only_first_definition = true,
      all_references = false,
      filter_references_pattern = "<module",
      virt_text_pos = "eol",
      all_frames = false,
      virt_lines = false,
      virt_text_win_col = nil,
    })

    -- Auto-open/close DAP UI
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end

    -- Keymaps
    vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "ブレークポイント切り替え" })
    vim.keymap.set("n", "<leader>dB", function()
      dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
    end, { desc = "条件付きブレークポイント" })
    vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "デバッグ開始/続行" })
    vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "ステップイン" })
    vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "ステップオーバー" })
    vim.keymap.set("n", "<leader>dO", dap.step_out, { desc = "ステップアウト" })
    vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "REPLを開く" })
    vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "最後のデバッグ構成を再実行" })
    vim.keymap.set("n", "<leader>dt", dapui.toggle, { desc = "DAP UIを切り替え" })
    vim.keymap.set("n", "<leader>dx", dap.terminate, { desc = "デバッグを終了" })
    vim.keymap.set("n", "<leader>dh", function()
      require("dap.ui.widgets").hover()
    end, { desc = "ホバー情報" })

    -- Diagnostic signs
    vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DiagnosticError", linehl = "", numhl = "" })
    vim.fn.sign_define("DapBreakpointCondition", { text = "", texthl = "DiagnosticWarn", linehl = "", numhl = "" })
    vim.fn.sign_define("DapLogPoint", { text = "", texthl = "DiagnosticInfo", linehl = "", numhl = "" })
    vim.fn.sign_define("DapStopped", { text = "→", texthl = "DiagnosticInfo", linehl = "", numhl = "" })
    vim.fn.sign_define("DapBreakpointRejected", { text = "", texthl = "DiagnosticHint", linehl = "", numhl = "" })
  end,
}
