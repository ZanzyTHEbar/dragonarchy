-- In-buffer markdown preview with markview.nvim (not glow, not browser).
-- ponytail: do NOT lazy-load this plugin (upstream requirement) and do NOT
-- enable render-markdown.nvim alongside it (conceal/extmark fight).
return {
  {
    'OXY2DEV/markview.nvim',
    lazy = false,
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    opts = {
      preview = {
        modes = { 'n', 'no', 'c', 't' },
        hybrid_modes = { 'n' },
        linewise_hybrid_mode = true,
      },
    },
    keys = {
      { '<leader>mr', '<cmd>Markview toggle<cr>', desc = '[M]arkdown [R]ender toggle' },
      { '<leader>mh', '<cmd>Markview hybridToggle<cr>', desc = '[M]arkdown [H]ybrid toggle' },
      { '<leader>ms', '<cmd>Markview splitToggle<cr>', desc = '[M]arkdown [S]plit toggle' },
      { '<leader>mo', '<cmd>Markview open<cr>', desc = '[M]arkdown [O]pen link' },
    },
  },
}
