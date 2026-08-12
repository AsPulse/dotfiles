-- AI エージェントへ渡すプロンプトを ~/snippets から呼び出すためのピッカー。
-- herdr-notepad (= 素の nvim) から使うので、外部プラグインには依存しない。
local M = {}

--- @param opts SnipdeckOptions?
function M.setup(opts) require('snipdeck.config').setup(opts) end

function M.open() require('snipdeck.ui').open() end

--- 先頭の見出しらしい行からスニペット名の候補を作る。
--- @param lines string[]
--- @return string
local function suggest_name(lines)
  for _, line in ipairs(lines) do
    local text = vim.trim(line):gsub('^#+%s*', ''):gsub('^[-*+>]%s+', '')
    if text ~= '' then
      text = text:gsub('[%s/\\:*?"<>|]+', '-'):gsub('^-+', ''):gsub('-+$', '')
      if text ~= '' then return vim.fn.strcharpart(text, 0, 32) end
    end
  end
  return ''
end

--- 現在のバッファ (または範囲) をスニペットとして保存する。
--- @param opts { name: string?, range: integer[]? }?
function M.save(opts)
  opts = opts or {}
  local store = require('snipdeck.store')
  local ui = require('snipdeck.ui')
  local buf = vim.api.nvim_get_current_buf()

  local lines = opts.range and vim.api.nvim_buf_get_lines(buf, opts.range[1] - 1, opts.range[2], false)
    or vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  while #lines > 0 and vim.trim(lines[#lines]) == '' do
    table.remove(lines)
  end
  if #lines == 0 then
    vim.notify('保存する内容がありません', vim.log.levels.WARN, { title = 'Snipdeck' })
    return
  end

  local function write(name)
    local path, err = store.resolve(name)
    if not path then
      vim.notify(err or '名前を解決できません', vim.log.levels.ERROR, { title = 'Snipdeck' })
      return
    end
    if vim.fn.filereadable(path) == 1 and not ui.confirm(path .. ' を上書きしますか?') then return end
    local ok, save_err = store.save(path, lines)
    if not ok then
      vim.notify(save_err or '保存に失敗しました', vim.log.levels.ERROR, { title = 'Snipdeck' })
      return
    end
    vim.notify(vim.fn.fnamemodify(path, ':~') .. ' に保存しました', vim.log.levels.INFO, { title = 'Snipdeck' })
  end

  if opts.name and opts.name ~= '' then
    write(opts.name)
  else
    vim.ui.input({ prompt = 'スニペット名: ', default = suggest_name(lines) }, function(input)
      if input and vim.trim(input) ~= '' then write(input) end
    end)
  end
end

return M
