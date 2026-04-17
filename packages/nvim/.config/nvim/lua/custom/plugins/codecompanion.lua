return {
  'olimorris/codecompanion.nvim',
  cmd = {
    'CodeCompanion',
    'CodeCompanionActions',
    'CodeCompanionChat',
    'CodeCompanionCmd',
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
    'saghen/blink.cmp',
  },
  keys = {
    {
      '<leader>aa',
      function()
        require('codecompanion').actions()
      end,
      desc = '[A]I [A]ctions',
    },
    {
      '<leader>ac',
      function()
        require('codecompanion').chat()
      end,
      desc = '[A]I [C]hat',
    },
    {
      '<leader>at',
      function()
        require('codecompanion').toggle()
      end,
      desc = '[A]I [T]oggle',
    },
  },
  opts = {
    adapters = {
      acp = {
        opencode = function()
          return require('codecompanion.adapters').extend('opencode', {
            defaults = {
              timeout = 20000,
            },
          })
        end,
      },
    },
    display = {
      action_palette = {
        height = 12,
        provider = 'snacks',
        width = 95,
      },
      chat = {
        intro_message = 'CodeCompanion ready. Press ? for keymaps',
        show_settings = false,
        start_in_insert_mode = false,
        window = {
          border = 'single',
          full_height = true,
          layout = 'vertical',
          position = 'right',
          relative = 'editor',
          width = 0.42,
          opts = {
            breakindent = true,
            linebreak = true,
            number = false,
            relativenumber = false,
            signcolumn = 'no',
            wrap = true,
          },
        },
      },
    },
    interactions = {
      chat = {
        adapter = 'opencode',
        opts = {
          completion_provider = 'blink',
        },
        slash_commands = {
          ['buffer'] = {
            opts = { provider = 'snacks' },
          },
          ['fetch'] = {
            opts = { provider = 'snacks' },
          },
          ['file'] = {
            opts = { provider = 'snacks' },
          },
          ['help'] = {
            opts = { provider = 'snacks' },
          },
          ['image'] = {
            opts = { provider = 'snacks' },
          },
          ['symbols'] = {
            opts = { provider = 'snacks' },
          },
        },
      },
    },
  },
}
