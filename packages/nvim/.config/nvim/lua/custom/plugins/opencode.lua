return {
  'nickjvandyke/opencode.nvim',
  version = '*',
  dependencies = {
    'folke/snacks.nvim',
  },
  init = function()
    local opencode_cmd = 'opencode --port'
    local terminal_opts = {
      auto_close = false,
      auto_insert = false,
      interactive = true,
      win = {
        enter = false,
        position = 'bottom',
        height = math.max(12, math.floor(vim.o.lines * 0.3)),
        on_win = function(win)
          require('opencode.terminal').setup(win.win)
        end,
      },
    }

    vim.g.opencode_opts = {
      server = {
        start = function()
          Snacks.terminal.open(opencode_cmd, terminal_opts)
        end,
        stop = function()
          local terminal = Snacks.terminal.get(opencode_cmd, vim.tbl_extend('force', terminal_opts, { create = false }))
          if terminal then
            terminal:close()
          end
        end,
        toggle = function()
          Snacks.terminal.toggle(opencode_cmd, terminal_opts)
        end,
      },
      prompts = {
        ask = { ask = true, prompt = '', submit = true },
        diagnostics = { prompt = 'Explain @diagnostics', submit = true },
        explain = { prompt = 'Explain @this and its context', submit = true },
        fix = { prompt = 'Fix @diagnostics', submit = true },
        implement = { prompt = 'Implement @this', submit = true },
        review = { prompt = 'Review @this for correctness and readability', submit = true },
        test = { prompt = 'Add tests for @this', submit = true },
      },
      ask = {
        prompt = 'OpenCode: ',
        snacks = {
          icon = '󰚩 ',
          win = {
            title = 'OpenCode',
            title_pos = 'left',
          },
        },
      },
      select = {
        prompt = 'OpenCode',
        sections = {
          prompts = true,
          commands = {
            ['session.new'] = 'Start a new session',
            ['session.select'] = 'Select a session',
            ['session.share'] = 'Share the current session',
            ['session.interrupt'] = 'Interrupt the current session',
            ['session.compact'] = 'Compact the current session',
            ['session.undo'] = 'Undo the last action',
            ['session.redo'] = 'Redo the last undone action',
            ['agent.cycle'] = 'Cycle the active agent',
            ['prompt.submit'] = 'Submit the current prompt',
            ['prompt.clear'] = 'Clear the current prompt',
          },
          server = true,
        },
        snacks = {
          layout = {
            hidden = {},
            preset = 'vscode',
          },
          preview = 'preview',
        },
      },
      lsp = {
        enabled = true,
        handlers = {
          code_action = { enabled = true },
          hover = { enabled = true },
        },
      },
      events = {
        enabled = true,
        permissions = {
          enabled = true,
          edits = {
            enabled = true,
          },
          idle_delay_ms = 1000,
        },
        reload = true,
      },
    }
  end,
  keys = {
    {
      '<leader>oa',
      function()
        require('opencode').ask('@this: ', { submit = true })
      end,
      desc = '[O]penCode [A]sk',
      mode = { 'n', 'x' },
    },
    {
      '<leader>os',
      function()
        require('opencode').select()
      end,
      desc = '[O]penCode [S]elect',
    },
    {
      '<leader>oo',
      function()
        require('opencode').toggle()
      end,
      desc = '[O]penCode T[o]ggle',
      mode = { 'n', 't' },
    },
    {
      '<leader>on',
      function()
        require('opencode').command 'session.new'
      end,
      desc = '[O]penCode [N]ew session',
    },
    {
      '<leader>oS',
      function()
        require('opencode').command 'session.select'
      end,
      desc = '[O]penCode [S]elect session',
    },
    {
      '<leader>oc',
      function()
        require('opencode').command 'session.compact'
      end,
      desc = '[O]penCode [C]ompact session',
    },
    {
      '<leader>oi',
      function()
        require('opencode').command 'session.interrupt'
      end,
      desc = '[O]penCode [I]nterrupt',
    },
    {
      '<leader>or',
      function()
        require('opencode').prompt 'review'
      end,
      desc = '[O]penCode [R]eview',
      mode = { 'n', 'x' },
    },
    {
      '<leader>of',
      function()
        require('opencode').prompt 'fix'
      end,
      desc = '[O]penCode [F]ix diagnostics',
      mode = { 'n', 'x' },
    },
    {
      '<leader>ot',
      function()
        require('opencode').prompt 'test'
      end,
      desc = '[O]penCode [T]est helper',
      mode = { 'n', 'x' },
    },
  },
}
