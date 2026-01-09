-- リーダーキーを最初に設定
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- コア設定を読み込み
require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
