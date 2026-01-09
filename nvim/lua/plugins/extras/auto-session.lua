return {
  "rmagatti/auto-session",
  config = function()
    require("auto-session").setup({
      log_level = "error",
      auto_session_enable_last_session = false,
      auto_session_root_dir = vim.fn.stdpath("data") .. "/sessions/",
      auto_session_enabled = true,
      auto_save_enabled = true,
      auto_restore_enabled = true,
      auto_session_suppress_dirs = {
        "~/",
        "~/Downloads",
        "~/Documents",
        "~/Desktop",
        "/",
      },
      auto_session_use_git_branch = false,
      auto_session_create_enabled = true,
      session_lens = {
        buftypes_to_ignore = {},
        load_on_setup = true,
        theme_conf = { border = true },
        previewer = false,
      },
    })

    -- キーマップ
    vim.keymap.set("n", "<leader>ss", "<cmd>SessionSave<cr>", { desc = "セッション保存" })
    vim.keymap.set("n", "<leader>sr", "<cmd>SessionRestore<cr>", { desc = "セッション復元" })
    vim.keymap.set("n", "<leader>sd", "<cmd>SessionDelete<cr>", { desc = "セッション削除" })
    vim.keymap.set("n", "<leader>sf", "<cmd>SessionSearch<cr>", { desc = "セッション検索" })
  end,
}
