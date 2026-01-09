return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    { "antosha417/nvim-lsp-file-operations", config = true },
    { "folke/neodev.nvim", opts = {} },
  },
  config = function()
    local lspconfig = require("lspconfig")
    local cmp_nvim_lsp = require("cmp_nvim_lsp")
    local keymap = vim.keymap.set

    -- LSP keymaps on_attach
    local on_attach = function(client, bufnr)
      local opts = { buffer = bufnr, silent = true }

      keymap("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "宣言へ移動" }))
      keymap("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "定義へ移動" }))
      keymap("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend("force", opts, { desc = "実装へ移動" }))
      keymap("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "参照を検索" }))
      keymap("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "ホバー情報" }))
      keymap("n", "<leader>lh", vim.lsp.buf.signature_help, vim.tbl_extend("force", opts, { desc = "シグネチャヘルプ" }))
      keymap("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "リネーム" }))
      keymap("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "コードアクション" }))
      keymap("n", "<leader>cf", vim.lsp.buf.format, vim.tbl_extend("force", opts, { desc = "フォーマット" }))
      keymap("n", "[d", vim.diagnostic.goto_prev, vim.tbl_extend("force", opts, { desc = "前の診断" }))
      keymap("n", "]d", vim.diagnostic.goto_next, vim.tbl_extend("force", opts, { desc = "次の診断" }))
      keymap("n", "<leader>ld", vim.diagnostic.open_float, vim.tbl_extend("force", opts, { desc = "診断を表示" }))
      keymap("n", "<leader>lq", vim.diagnostic.setloclist, vim.tbl_extend("force", opts, { desc = "診断リスト" }))
    end

    -- Enhanced capabilities with nvim-cmp
    local capabilities = cmp_nvim_lsp.default_capabilities()

    -- Configure diagnostics
    vim.diagnostic.config({
      virtual_text = {
        prefix = "●",
        source = "if_many",
      },
      signs = true,
      underline = true,
      update_in_insert = false,
      severity_sort = true,
      float = {
        border = "rounded",
        source = "always",
        header = "",
        prefix = "",
      },
    })

    -- Diagnostic signs
    local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    -- TypeScript/JavaScript
    lspconfig.ts_ls.setup({
      on_attach = on_attach,
      capabilities = capabilities,
      settings = {
        typescript = {
          inlayHints = {
            includeInlayParameterNameHints = "all",
            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
            includeInlayFunctionParameterTypeHints = true,
            includeInlayVariableTypeHints = true,
            includeInlayVariableTypeHintsWhenTypeMatchesName = false,
            includeInlayPropertyDeclarationTypeHints = true,
            includeInlayFunctionLikeReturnTypeHints = true,
            includeInlayEnumMemberValueHints = true,
          },
        },
        javascript = {
          inlayHints = {
            includeInlayParameterNameHints = "all",
            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
            includeInlayFunctionParameterTypeHints = true,
            includeInlayVariableTypeHints = true,
            includeInlayVariableTypeHintsWhenTypeMatchesName = false,
            includeInlayPropertyDeclarationTypeHints = true,
            includeInlayFunctionLikeReturnTypeHints = true,
            includeInlayEnumMemberValueHints = true,
          },
        },
      },
    })

    -- Go
    lspconfig.gopls.setup({
      on_attach = on_attach,
      capabilities = capabilities,
      settings = {
        gopls = {
          analyses = {
            unusedparams = true,
            shadow = true,
          },
          staticcheck = true,
          gofumpt = true,
          hints = {
            assignVariableTypes = true,
            compositeLiteralFields = true,
            compositeLiteralTypes = true,
            constantValues = true,
            functionTypeParameters = true,
            parameterNames = true,
            rangeVariableTypes = true,
          },
        },
      },
    })

    -- Python
    lspconfig.pyright.setup({
      on_attach = on_attach,
      capabilities = capabilities,
      settings = {
        python = {
          analysis = {
            autoSearchPaths = true,
            diagnosticMode = "workspace",
            useLibraryCodeForTypes = true,
            typeCheckingMode = "basic",
          },
        },
      },
    })

    -- Scala (Metals)
    lspconfig.metals.setup({
      on_attach = on_attach,
      capabilities = capabilities,
      init_options = {
        statusBarProvider = "on",
      },
    })

    -- Lua (for Neovim config)
    lspconfig.lua_ls.setup({
      on_attach = on_attach,
      capabilities = capabilities,
      settings = {
        Lua = {
          diagnostics = {
            globals = { "vim" },
          },
          workspace = {
            library = vim.api.nvim_get_runtime_file("", true),
            checkThirdParty = false,
          },
          telemetry = {
            enable = false,
          },
          completion = {
            callSnippet = "Replace",
          },
        },
      },
    })

    -- JSON
    lspconfig.jsonls.setup({
      on_attach = on_attach,
      capabilities = capabilities,
    })

    -- YAML
    lspconfig.yamlls.setup({
      on_attach = on_attach,
      capabilities = capabilities,
    })

    -- HTML
    lspconfig.html.setup({
      on_attach = on_attach,
      capabilities = capabilities,
    })

    -- CSS
    lspconfig.cssls.setup({
      on_attach = on_attach,
      capabilities = capabilities,
    })
  end,
}
