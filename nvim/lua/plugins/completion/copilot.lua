return {
  "github/copilot.vim",
  event = "InsertEnter",
  config = function()
    -- Copilotのデフォルトキーマップを無効化（カスタマイズする場合）
    vim.g.copilot_no_tab_map = false

    -- Copilotのサジェストを受け入れるキーマップ
    -- デフォルト: Tab
    -- カスタマイズ例:
    -- vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
    --   expr = true,
    --   replace_keycodes = false,
    -- })

    -- Copilotを有効/無効にするコマンド
    vim.keymap.set("n", "<leader>ce", ":Copilot enable<CR>", { desc = "Copilotを有効化" })
    vim.keymap.set("n", "<leader>cd", ":Copilot disable<CR>", { desc = "Copilotを無効化" })

    -- Copilotのステータス確認
    vim.keymap.set("n", "<leader>cs", ":Copilot status<CR>", { desc = "Copilotステータス" })

    -- 特定のファイルタイプでCopilotを無効化する場合
    vim.g.copilot_filetypes = {
      ["*"] = true,
      -- gitcommit = false,
      -- markdown = false,
    }

    -- ノート: 初回使用時には :Copilot auth を実行して認証が必要です
  end,
}
