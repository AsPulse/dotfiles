local config = require('snipdeck.config')

local uv = vim.uv or vim.loop

local M = {}

--- @class SnipdeckItem
--- @field path string 絶対パス
--- @field rel string スニペットディレクトリからの相対パス (usage のキー)
--- @field dir string '' または 'sub/'
--- @field name string 拡張子付きファイル名
--- @field key string 拡張子を落とした表示名 (fuzzy 検索の対象)
--- @field lines string[]
--- @field bytes integer
--- @field mtime integer
--- @field count integer 使用回数
--- @field last integer 最終使用時刻 (unix time)

local function allowed(name)
  local ext = name:match('%.([^./]+)$')
  if not ext then return false end
  return vim.tbl_contains(config.options.extensions, ext:lower())
end

local function hidden(rel) return rel:sub(1, 1) == '.' or rel:find('/%.') ~= nil end

--- @return table<string, { count: integer, last: integer }>
function M.usage()
  local path = config.options.usage_file
  if vim.fn.filereadable(path) == 0 then return {} end
  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), '\n'))
  if not ok or type(decoded) ~= 'table' then return {} end
  return decoded
end

function M.write_usage(usage)
  local path = config.options.usage_file
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile({ vim.json.encode(usage) }, path)
end

--- @param rel string
function M.record(rel)
  local usage = M.usage()
  local entry = usage[rel] or {}
  usage[rel] = { count = (tonumber(entry.count) or 0) + 1, last = os.time() }
  M.write_usage(usage)
end

--- @return SnipdeckItem[]
function M.items()
  local root = config.dir()
  local items = {}
  local stat = uv.fs_stat(root)
  if not stat or stat.type ~= 'directory' then return items end

  local usage = M.usage()
  for rel, type_ in vim.fs.dir(root, { depth = 5 }) do
    if (type_ == 'file' or type_ == 'link') and allowed(rel) and not hidden(rel) then
      local path = root .. '/' .. rel
      local st = uv.fs_stat(path)
      if st and st.type == 'file' then
        local recorded = usage[rel] or {}
        local dir = rel:match('^(.*/)') or ''
        local name = rel:sub(#dir + 1)
        -- readfile は NUL を \n として返し、それは nvim_buf_set_lines が受け付けない
        local lines = vim.tbl_map(
          function(line) return (line:gsub('\r$', ''):gsub('\n', ' ')) end,
          vim.fn.readfile(path, '', config.options.max_lines)
        )
        table.insert(items, {
          path = path,
          rel = rel,
          dir = dir,
          name = name,
          key = dir .. name:gsub('%.[^./]+$', ''),
          lines = lines,
          bytes = st.size,
          mtime = math.floor(st.mtime.sec),
          count = tonumber(recorded.count) or 0,
          last = tonumber(recorded.last) or 0,
        })
      end
    end
  end
  return items
end

--- スニペット名を書き込み先の絶対パスへ解決する。
--- @param name string
--- @return string? path, string? err
function M.resolve(name)
  local cleaned = vim.trim(name or ''):gsub('^/+', '')
  if cleaned == '' then return nil, 'スニペット名が空です' end
  if cleaned:find('%.%.') then return nil, '.. を含む名前は使えません' end
  if not cleaned:match('%.[^./]+$') then cleaned = cleaned .. '.txt' end
  return config.dir() .. '/' .. cleaned, nil
end

--- @param path string
--- @param lines string[]
--- @return boolean ok, string? err
function M.save(path, lines)
  local dir = vim.fs.dirname(path)
  if vim.fn.isdirectory(dir) == 0 and vim.fn.mkdir(dir, 'p') == 0 then
    return false, dir .. ' を作成できません'
  end
  if vim.fn.writefile(lines, path) ~= 0 then return false, path .. ' に書き込めません' end
  return true, nil
end

--- @param item SnipdeckItem
--- @return boolean ok
function M.delete(item)
  if vim.fn.delete(item.path) ~= 0 then return false end
  local usage = M.usage()
  usage[item.rel] = nil
  M.write_usage(usage)
  return true
end

return M
