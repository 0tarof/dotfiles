return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  config = function()
    local wk = require("which-key")

    wk.setup({
      preset = "modern",
      icons = {
        breadcrumb = "»",
        separator = "➜",
        group = "+",
      },
      win = {
        border = "rounded",
        position = "bottom",
        padding = { 2, 2, 2, 2 },
      },
      layout = {
        height = { min = 4, max = 25 },
        width = { min = 20, max = 50 },
        spacing = 3,
        align = "left",
      },
    })

    -- キーマップのグループ設定
    wk.add({
      { "<leader>f", group = "ファイル/検索" },
      { "<leader>b", group = "バッファ" },
      { "<leader>g", group = "Git" },
      { "<leader>l", group = "LSP" },
      { "<leader>d", group = "デバッグ" },
      { "<leader>t", group = "ターミナル" },
      { "<leader>c", group = "コード" },
      { "<leader>w", desc = "保存" },
      { "<leader>q", desc = "終了" },
      { "<leader>e", desc = "ファイルエクスプローラー切り替え" },
    })
  end,
}
