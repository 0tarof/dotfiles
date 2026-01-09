local keymap = vim.keymap.set

-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", { desc = "左のウィンドウへ移動" })
keymap("n", "<C-j>", "<C-w>j", { desc = "下のウィンドウへ移動" })
keymap("n", "<C-k>", "<C-w>k", { desc = "上のウィンドウへ移動" })
keymap("n", "<C-l>", "<C-w>l", { desc = "右のウィンドウへ移動" })

-- Resize windows
keymap("n", "<C-Up>", ":resize -2<CR>", { desc = "ウィンドウの高さを縮小" })
keymap("n", "<C-Down>", ":resize +2<CR>", { desc = "ウィンドウの高さを拡大" })
keymap("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "ウィンドウの幅を縮小" })
keymap("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "ウィンドウの幅を拡大" })

-- Buffer navigation
keymap("n", "<S-l>", ":bnext<CR>", { desc = "次のバッファ" })
keymap("n", "<S-h>", ":bprevious<CR>", { desc = "前のバッファ" })
keymap("n", "<leader>bd", ":bdelete<CR>", { desc = "バッファを閉じる" })

-- Clear search highlighting
keymap("n", "<Esc>", ":nohlsearch<CR>", { silent = true })

-- Better indenting
keymap("v", "<", "<gv", { desc = "インデントを減らす" })
keymap("v", ">", ">gv", { desc = "インデントを増やす" })

-- Move text up and down
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "選択行を下に移動" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "選択行を上に移動" })

-- Keep cursor centered
keymap("n", "<C-d>", "<C-d>zz", { desc = "半画面下にスクロール（中央維持）" })
keymap("n", "<C-u>", "<C-u>zz", { desc = "半画面上にスクロール（中央維持）" })
keymap("n", "n", "nzzzv", { desc = "次の検索結果（中央維持）" })
keymap("n", "N", "Nzzzv", { desc = "前の検索結果（中央維持）" })

-- File explorer (nvim-tree)
keymap("n", "<leader>e", ":NvimTreeToggle<CR>", { desc = "ファイルエクスプローラー切り替え" })

-- Telescope
keymap("n", "<leader>ff", ":Telescope find_files<CR>", { desc = "ファイル検索" })
keymap("n", "<leader>fg", ":Telescope live_grep<CR>", { desc = "文字列検索" })
keymap("n", "<leader>fb", ":Telescope buffers<CR>", { desc = "バッファ検索" })
keymap("n", "<leader>fh", ":Telescope help_tags<CR>", { desc = "ヘルプタグ検索" })
keymap("n", "<leader>fr", ":Telescope oldfiles<CR>", { desc = "最近開いたファイル" })

-- Save and quit
keymap("n", "<leader>w", ":w<CR>", { desc = "保存" })
keymap("n", "<leader>q", ":q<CR>", { desc = "終了" })
