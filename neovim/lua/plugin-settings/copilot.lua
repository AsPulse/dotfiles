--- @type LazyPluginSpec[]
return {
  {
    'zbirenbaum/copilot.lua',
    requires = {
      'copilotlsp-nvim/copilot-lsp',
    },
    cmd = 'Copilot',
    event = 'InsertEnter',
    opts = {
      suggestion = {
        auto_trigger = true,
        keymap = {
          accept = '<C-f>',
          accept_word = '<C-w>',
          accept_line = '<C-l>',
          next = '<C-[>',
          prev = '<C-]>',
          dismiss = '<C-n>',
        },
      },
    },
  },
}
