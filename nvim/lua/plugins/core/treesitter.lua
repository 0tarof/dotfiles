return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = {
    "windwp/nvim-ts-autotag",
  },
  config = function()
    require("nvim-treesitter.configs").setup({
      -- 自動インストールする言語
      ensure_installed = {
        "typescript",
        "javascript",
        "tsx",
        "go",
        "python",
        "scala",
        "lua",
        "vim",
        "vimdoc",
        "json",
        "yaml",
        "toml",
        "html",
        "css",
        "markdown",
        "markdown_inline",
        "bash",
        "dockerfile",
        "gitignore",
      },

      -- 自動インストール有効化
      auto_install = true,

      -- ハイライト
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },

      -- インデント
      indent = {
        enable = true,
      },

      -- Autotag（HTMLタグ自動閉じ）
      autotag = {
        enable = true,
      },
    })
  end,
}
