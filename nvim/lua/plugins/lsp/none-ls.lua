return {
  "nvimtools/none-ls.nvim",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    local null_ls = require("null-ls")

    local formatting = null_ls.builtins.formatting
    local diagnostics = null_ls.builtins.diagnostics

    null_ls.setup({
      sources = {
        -- TypeScript/JavaScript
        formatting.prettier.with({
          extra_filetypes = { "svelte" },
        }),
        diagnostics.eslint_d.with({
          condition = function(utils)
            return utils.root_has_file({ ".eslintrc.js", ".eslintrc.json", ".eslintrc.cjs" })
          end,
        }),

        -- Go
        formatting.gofmt,
        formatting.goimports,

        -- Python
        formatting.black,
        formatting.isort,
        diagnostics.pylint,
        diagnostics.mypy,

        -- Scala
        formatting.scalafmt,

        -- Lua
        formatting.stylua,
      },
      -- Format on save
      on_attach = function(client, bufnr)
        if client.supports_method("textDocument/formatting") then
          vim.api.nvim_create_autocmd("BufWritePre", {
            group = vim.api.nvim_create_augroup("LspFormatting", { clear = true }),
            buffer = bufnr,
            callback = function()
              vim.lsp.buf.format({
                bufnr = bufnr,
                filter = function(c)
                  return c.name == "null-ls"
                end,
              })
            end,
          })
        end
      end,
    })
  end,
}
