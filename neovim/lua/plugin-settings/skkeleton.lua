--- @type LazyPluginSpec[]
return {
  {
    'vim-skk/skkeleton',
    event = { 'InsertEnter', 'CmdlineEnter' },
    cmd = { 'Telescope' },
    dependencies = { 'vim-denops/denops.vim', 'yuki-yano/denops-lazy.nvim' },
    config = function()
      require('denops-lazy').load('skkeleton', { wait_load = false })
      vim.fn['skkeleton#config']({
        debug = false,
        eggLikeNewline = true,
        globalDictionaries = {
          '~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries/SKK-JISYO.L',
        },
        globalKanaTableFiles = {
          { '~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Settings/kana-rule.conf', 'utf8' },
        },
        userDictionary = '~/.skk/skkeleton.txt',
      })
      vim.keymap.set({ 'i', 't' }, '<C-j>', '<Plug>(skkeleton-enable)', { remap = true })
      vim.keymap.set({ 'i', 't' }, 'l', function()
        if vim.fn['skkeleton#is_enabled']() == 1 then
          return '<Plug>(skkeleton-disable)'
        else
          return 'l'
        end
      end, { expr = true, remap = true })
      vim.fn['skkeleton#register_keymap']('henkan', 'q', 'katakana')
      vim.fn['skkeleton#register_keymap']('henkan', '<C-q>', 'hankatakana')
    end,
  },
  {
    'delphinus/skkeleton_indicator.nvim',
    event = { 'InsertEnter', 'CmdlineEnter' },
    cmd = { 'Telescope' },
    opts = {},
  },
}
