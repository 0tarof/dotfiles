local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight on yank
autocmd("TextYankPost", {
  group = augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
  desc = "ヤンク時にハイライト表示",
})

-- Auto-format on save
autocmd("BufWritePre", {
  group = augroup("auto_format", { clear = true }),
  pattern = { "*.ts", "*.tsx", "*.js", "*.jsx", "*.go", "*.py", "*.scala" },
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
  desc = "保存時に自動フォーマット",
})

-- Remove trailing whitespace
autocmd("BufWritePre", {
  group = augroup("trim_whitespace", { clear = true }),
  pattern = "*",
  command = [[%s/\s\+$//e]],
  desc = "保存時に末尾の空白を削除",
})

-- Close some filetypes with <q>
autocmd("FileType", {
  group = augroup("close_with_q", { clear = true }),
  pattern = { "qf", "help", "man", "notify", "lspinfo", "spectre_panel" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
  desc = "qキーで特定のファイルタイプを閉じる",
})

-- Auto-create directories when saving a file
autocmd("BufWritePre", {
  group = augroup("auto_create_dir", { clear = true }),
  callback = function(event)
    local file = vim.loop.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
  desc = "ファイル保存時にディレクトリを自動作成",
})

-- Restore cursor position
autocmd("BufReadPost", {
  group = augroup("restore_cursor", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
  desc = "ファイルを開いた際にカーソル位置を復元",
})
