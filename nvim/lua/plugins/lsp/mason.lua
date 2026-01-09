return {
  "williamboman/mason.nvim",
  dependencies = {
    "williamboman/mason-lspconfig.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },
  config = function()
    local mason = require("mason")
    local mason_lspconfig = require("mason-lspconfig")
    local mason_tool_installer = require("mason-tool-installer")

    mason.setup({
      ui = {
        border = "rounded",
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    })

    mason_lspconfig.setup({
      ensure_installed = {
        "ts_ls",           -- TypeScript/JavaScript
        "gopls",           -- Go
        "pyright",         -- Python
        "metals",          -- Scala
        "lua_ls",          -- Lua (Neovim設定用)
        "jsonls",          -- JSON
        "yamlls",          -- YAML
        "html",            -- HTML
        "cssls",           -- CSS
      },
      automatic_installation = true,
    })

    mason_tool_installer.setup({
      ensure_installed = {
        -- Formatters
        "prettier",        -- TypeScript/JavaScript/HTML/CSS
        "gofmt",          -- Go
        "goimports",      -- Go imports
        "black",          -- Python
        "isort",          -- Python imports
        "scalafmt",       -- Scala

        -- Linters
        "eslint_d",       -- TypeScript/JavaScript
        "golangci-lint",  -- Go
        "pylint",         -- Python
        "mypy",           -- Python type checking

        -- Debuggers
        "js-debug-adapter",     -- TypeScript/JavaScript
        "delve",               -- Go
        "debugpy",             -- Python

        -- Others
        "codelldb",       -- General purpose debugger
      },
    })
  end,
}
