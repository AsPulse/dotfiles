-- Ccsend command to send buffer content to Zellij
vim.api.nvim_create_user_command('Ccsend', function()
  -- Get the current buffer content
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local buffer_content = table.concat(lines, '\n')

  -- Escape special characters for shell command
  local escaped_content = buffer_content
    :gsub('\\', '\\\\') -- Escape backslashes first
    :gsub('"', '\\"') -- Escape double quotes
    :gsub('`', '\\`') -- Escape backticks
    :gsub('%$', '\\$') -- Escape dollar signs

  -- Execute the zellij commands
  local cmd = string.format('zellij action move-focus up && zellij action write-chars -- "%s"', escaped_content)
  vim.fn.system(cmd)

  -- Clear the buffer content
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
end, {})
