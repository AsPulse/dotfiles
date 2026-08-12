vim.api.nvim_create_user_command(
  'Snipdeck',
  function() require('snipdeck').open() end,
  { desc = 'Snipdeck: スニペットピッカーを開く' }
)

vim.api.nvim_create_user_command(
  'SnipdeckSave',
  function(args)
    require('snipdeck').save({
      name = args.args ~= '' and args.args or nil,
      range = args.range > 0 and { args.line1, args.line2 } or nil,
    })
  end,
  { nargs = '?', range = true, desc = 'Snipdeck: バッファ/範囲をスニペットとして保存' }
)

vim.keymap.set(
  'n',
  '<leader>sn',
  function() require('snipdeck').open() end,
  { desc = 'Snipdeck: スニペットを挿入' }
)

vim.keymap.set(
  'n',
  '<leader>sw',
  function() require('snipdeck').save() end,
  { desc = 'Snipdeck: バッファをスニペットとして保存' }
)

vim.keymap.set('x', '<leader>sw', function()
  local from, to = vim.fn.line('v'), vim.fn.line('.')
  if from > to then
    from, to = to, from
  end
  -- vim.ui.input を出す前にビジュアルモードを抜ける
  vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'nx', false)
  require('snipdeck').save({ range = { from, to } })
end, { desc = 'Snipdeck: 選択範囲をスニペットとして保存' })
