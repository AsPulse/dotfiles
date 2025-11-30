local function try_load_workspace_async()
  local cwd      = vim.loop.cwd()
  local vim_path = cwd .. "/.vim/workspace.vim"
  local lua_path = cwd .. "/.vim/workspace.lua"
  local vim_local_path = cwd .. "/.vim/workspace.local.vim"
  local lua_local_path = cwd .. "/.vim/workspace.local.lua"

  local has_vim = vim.loop.fs_stat(vim_path) ~= nil
  local has_lua = vim.loop.fs_stat(lua_path) ~= nil
  local has_vim_local = vim.loop.fs_stat(vim_local_path) ~= nil
  local has_lua_local = vim.loop.fs_stat(lua_local_path) ~= nil
  if not (has_vim or has_lua or has_vim_local or has_lua_local) then return end

  vim.ui.input({ prompt = "Allow load .vim/workspace? (y/n) " }, function(input)
    if not input then return end
    local ans = input:lower():match("^%s*(%a)%s*$")
    if ans == "y" then
      if has_vim then vim.cmd("source " .. vim.fn.fnameescape(vim_path)) end
      if has_lua then vim.cmd("luafile " .. vim.fn.fnameescape(lua_path)) end
      if has_vim_local then vim.cmd("source " .. vim.fn.fnameescape(vim_local_path)) end
      if has_lua_local then vim.cmd("luafile " .. vim.fn.fnameescape(lua_local_path)) end
    end
  end)
end

vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
  group   = vim.api.nvim_create_augroup("WorkspaceConfig", { clear = true }),
  pattern = "*",
  callback = try_load_workspace_async,
})
