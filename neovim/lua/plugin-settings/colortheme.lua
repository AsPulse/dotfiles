--- @type LazyPluginSpec
return {
  'catppuccin/nvim',
  name = 'catppuccin',
  lazy = false,
  priority = 1000,
  --- @type CatppuccinOptions
  opts = {
    flavour = 'macchiato',
    integrations = {
      fern = true,
      snacks = {
        enabled = true,
        indent_scope_color = 'pink',
      },
    },
  },
  config = function(_, opts)
    require('catppuccin').setup(opts)
    vim.cmd.colorscheme('catppuccin')
  end,
}
