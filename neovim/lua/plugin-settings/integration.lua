--- @type LazyPluginSpec[]
return {
  {
    'wakatime/vim-wakatime',
    event = 'VeryLazy'
  },
  {
    'Allianaab2m/vimskey',
    event = 'VeryLazy',
    dependencies = { 'vim-denops/denops.vim' }
  },
  {
    'AsPulse/presence.nvim',
    branch = 'main',
    event = 'VeryLazy',
    opts = {
      auto_update = true,
      buttons = true,
    },
  },
}
