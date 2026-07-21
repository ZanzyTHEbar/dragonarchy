return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  opts = {
    bigfile = { enabled = true },
    explorer = { enabled = true },
    indent = { enabled = true },
    input = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    picker = {
      enabled = true,
      ui_select = true,
      layout = {
        preset = function()
          return vim.o.columns >= 140 and 'default' or 'vertical'
        end,
      },
      sources = {
        explorer = {
          auto_close = false,
          diagnostics = true,
          follow_file = true,
          focus = 'list',
          git_status = true,
          git_untracked = true,
          jump = { close = false },
          layout = {
            preset = 'sidebar',
            preview = false,
            layout = {
              position = 'left',
              width = 32,
            },
          },
          matcher = {
            fuzzy = false,
            sort_empty = false,
          },
          tree = true,
          watch = true,
          win = {
            list = {
              keys = {
                ['<Esc>'] = 'cancel',
                ['<leader>/'] = 'picker_grep',
                ['H'] = 'toggle_hidden',
                ['I'] = 'toggle_ignored',
                ['l'] = 'confirm',
                ['h'] = 'explorer_close',
              },
            },
          },
        },
      },
    },
    quickfile = { enabled = true },
    scope = { enabled = true },
    scroll = { enabled = true },
    statuscolumn = { enabled = true },
    terminal = {},
    words = { enabled = true },
  },
  keys = {
    { '<leader>sh', function() Snacks.picker.help() end, desc = '[S]earch [H]elp' },
    { '<leader>sk', function() Snacks.picker.keymaps() end, desc = '[S]earch [K]eymaps' },
    { '<leader>sf', function() Snacks.picker.files() end, desc = '[S]earch [F]iles' },
    { '<leader>ss', function() Snacks.picker() end, desc = '[S]earch [S]elect' },
    { '<leader>sw', function() Snacks.picker.grep_word() end, desc = '[S]earch current [W]ord', mode = { 'n', 'x' } },
    { '<leader>sg', function() Snacks.picker.grep() end, desc = '[S]earch by [G]rep' },
    { '<leader>sd', function() Snacks.picker.diagnostics() end, desc = '[S]earch [D]iagnostics' },
    { '<leader>sr', function() Snacks.picker.resume() end, desc = '[S]earch [R]esume' },
    { '<leader>s.', function() Snacks.picker.recent() end, desc = '[S]earch Recent Files ("." for repeat)' },
    { '<leader><leader>', function() Snacks.picker.buffers() end, desc = '[ ] Find existing buffers' },
    { '<leader>/', function() Snacks.picker.lines() end, desc = '[/] Search in current buffer' },
    { '<leader>s/', function() Snacks.picker.grep_buffers() end, desc = '[S]earch [/] in Open Files' },
    { '<leader>sn', function() Snacks.picker.files { cwd = vim.fn.stdpath 'config' } end, desc = '[S]earch [N]eovim files' },
    { '<leader>e', function() Snacks.explorer() end, desc = 'File [E]xplorer' },
    { '<leader>:', function() Snacks.picker.command_history() end, desc = 'Command History' },
    { '<leader>n', function() Snacks.notifier.show_history() end, desc = 'Notification History' },
  },
}
