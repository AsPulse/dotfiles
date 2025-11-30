--- @type LazyPluginSpec
return {
  'akinsho/bufferline.nvim',
  event = 'BufEnter *.*',
  branch = 'main',
  after = 'catppuccin',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },
  --- @type bufferline.UserConfig
  opts = {
    options = {
      show_buffer_close_icons = false,
      show_close_icon = false,
      indicator = {
        style = 'underline',
      },
      separator_style = { '', '' },
    },
    highlights = function(_)
      local theme = require('catppuccin.special.bufferline').get_theme()()

      local selected_buf_accent = '#ed8796'
      local selected_buf_bg = '#3d3345' -- #25273a + 12% #ed8796

      local selected_tab_accent = '#91d7e3'
      local selected_tab_bg = '#323c4e' -- #25273a + 12% #91d7e3

      for name, spec in pairs(theme) do
        if name:find('selected') then
          if name:find('tab') then
            spec.sp = selected_tab_accent
            spec.bg = selected_tab_bg
          else
            spec.sp = selected_buf_accent
            spec.bg = selected_buf_bg
          end
        end
      end

      return theme
    end,
  },
}
