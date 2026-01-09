local opt = vim.opt

-- UI
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.termguicolors = true
opt.showmode = false
opt.splitright = true
opt.splitbelow = true
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true

-- Performance
opt.updatetime = 250
opt.timeoutlen = 300
opt.lazyredraw = true

-- Files
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.undodir = os.getenv("HOME") .. "/.local/state/nvim/undo"

-- Completion
opt.completeopt = "menu,menuone,noselect"
opt.pumheight = 10

-- Misc
opt.clipboard = "unnamedplus" -- システムクリップボードと統合
opt.mouse = "a" -- すべてのモードでマウス有効化
