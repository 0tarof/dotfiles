return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "leoluz/nvim-dap-go",
    "mfussenegger/nvim-dap-python",
    "mxsdev/nvim-dap-vscode-js",
  },
  config = function()
    -- Go
    require("dap-go").setup()

    -- Python
    require("dap-python").setup("~/.local/share/nvim/mason/packages/debugpy/venv/bin/python")

    -- TypeScript/JavaScript
    require("dap-vscode-js").setup({
      debugger_path = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter",
      adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
    })

    local dap = require("dap")

    for _, language in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact" }) do
      dap.configurations[language] = {
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          cwd = "${workspaceFolder}",
        },
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach",
          processId = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
        },
        {
          type = "pwa-node",
          request = "launch",
          name = "Debug Jest Tests",
          runtimeExecutable = "node",
          runtimeArgs = {
            "./node_modules/jest/bin/jest.js",
            "--runInBand",
          },
          rootPath = "${workspaceFolder}",
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
          internalConsoleOptions = "neverOpen",
        },
      }
    end

    -- Scala (MetalsはビルトインでDAP対応)
    -- Metalsのデバッグは、Metals LSPサーバーが自動的に処理します
    -- 特別な設定は不要ですが、Metalsの設定でdebug機能を有効にする必要があります
  end,
}
