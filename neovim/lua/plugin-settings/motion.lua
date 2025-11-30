--- @type LazyPluginSpec[]
return {
  {
    'ggandor/lightspeed.nvim',
    event = 'BufEnter *.*',
    config = function()
      vim.api.nvim_del_keymap('n', 's')
      vim.api.nvim_del_keymap('n', 'S')
      vim.api.nvim_set_keymap( 'n', 's', '<Plug>Lightspeed_omni_s', {})
    end,
  }
}

