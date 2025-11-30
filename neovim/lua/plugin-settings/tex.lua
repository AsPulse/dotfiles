--- @type LazyPluginSpec[]
return {
  {
    'ryota2357/vim-skim-synctex',
    dependencies = 'vim-denops/denops.vim',
    config = function()
      vim.fn['synctex#option']('port', 8123)

      -- Add keybinding for forward search
      vim.keymap.set(
        'n',
        '<leader>fs',
        function() vim.fn['synctex#forwardSerch']() end,
        { desc = 'SyncTeX forward search' }
      )

      --- @type integer?
      local current_tex_buffer = nil

      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = '*.tex',
        callback = function()
          local new_buffer = vim.api.nvim_get_current_buf()
          if current_tex_buffer and current_tex_buffer ~= new_buffer then
            if vim.api.nvim_buf_is_valid(current_tex_buffer) then
              local prev_bufname = vim.api.nvim_buf_get_name(current_tex_buffer)
              if prev_bufname:match('%.tex$') then vim.fn['synctex#stop']() end
            end
          end
          vim.fn['synctex#start']()
          current_tex_buffer = new_buffer
        end,
      })

      vim.api.nvim_create_autocmd('BufLeave', {
        pattern = '*.tex',
        callback = function()
          local leaving_buffer = vim.api.nvim_get_current_buf()
          if leaving_buffer == current_tex_buffer then
            vim.defer_fn(function()
              local current_buf = vim.api.nvim_get_current_buf()
              local bufname = vim.api.nvim_buf_get_name(current_buf)
              if not bufname:match('%.tex$') then
                vim.fn['synctex#stop']()
                current_tex_buffer = nil
              end
            end, 10)
          end
        end,
      })
    end,
  },
}
