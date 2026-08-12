local config = require('snipdeck.config')
local store = require('snipdeck.store')

local M = {}

local ns = vim.api.nvim_create_namespace('snipdeck')

local ICON = {
  title = '',
  item = '󰈙',
  grep = '',
  prompt = '❯',
}

local SORTS = {
  { key = 'freq', label = '頻度順' },
  { key = 'recent', label = '更新順' },
  { key = 'name', label = '名前順' },
}

local HELP = {
  { '↵', '挿入' },
  { '^a', '末尾' },
  { '^r', '全置換' },
  { '^y', 'ヤンク' },
  { '^e', '編集' },
  { '^x', '削除' },
  { '^g', '並び順' },
  { '^t/^n', '移動' },
  { '^f/^b', 'スクロール' },
  { 'esc', '閉じる' },
}

--- @class SnipdeckEntry
--- @field item SnipdeckItem
--- @field pos integer[]? fuzzy 一致した文字位置 (0-based)
--- @field score integer
--- @field grep boolean? 名前ではなく本文が一致した

--- @type table?
local state = nil

local function fg_of(group)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  return hl.fg
end

local function setup_highlights()
  local link = {
    SnipdeckNormal = 'NormalFloat',
    SnipdeckBorder = 'FloatBorder',
    SnipdeckSelection = 'Visual',
    SnipdeckMark = 'Special',
    SnipdeckIcon = 'Function',
    SnipdeckDir = 'Comment',
    SnipdeckCount = 'Number',
    SnipdeckHeat = 'Number',
    SnipdeckHeatDim = 'NonText',
    SnipdeckBadge = 'DiagnosticHint',
    SnipdeckMeta = 'Comment',
    SnipdeckHelpDesc = 'Comment',
    SnipdeckHelpKey = 'Special',
    SnipdeckPrompt = 'Special',
    SnipdeckEmpty = 'Comment',
  }
  for name, target in pairs(link) do
    vim.api.nvim_set_hl(0, name, { link = target, default = true })
  end
  -- 一致文字とタイトルだけは link では太字を足せないので色をコピーして作る
  vim.api.nvim_set_hl(0, 'SnipdeckMatch', { fg = fg_of('Special'), bold = true, default = true })
  vim.api.nvim_set_hl(0, 'SnipdeckTitle', { fg = fg_of('Function'), bold = true, default = true })
end

local function dw(text) return vim.fn.strdisplaywidth(text) end

local function truncate(text, width)
  if dw(text) <= width then return text end
  if width <= 1 then return '' end
  local cut = text
  while dw(cut) > width - 1 and cut ~= '' do
    cut = vim.fn.strcharpart(cut, 0, vim.fn.strchars(cut) - 1)
  end
  return cut .. '…'
end

--- セグメント列を 1 行のテキストと highlight 範囲へ潰す。
--- @param segs table[] { text, hl? } の配列
--- @return string text, table[] hls, integer[] offsets
local function flatten(segs)
  local text, hls, offsets = '', {}, {}
  for i, seg in ipairs(segs) do
    offsets[i] = #text
    text = text .. seg[1]
    if seg[2] then table.insert(hls, { seg[2], offsets[i], #text }) end
  end
  return text, hls, offsets
end

local function pretty_bytes(n)
  if n < 1024 then return n .. ' B' end
  if n < 1024 * 1024 then return string.format('%.1f KB', n / 1024) end
  return string.format('%.1f MB', n / 1024 / 1024)
end

local function ago(ts)
  if ts <= 0 then return '' end
  local diff = os.time() - ts
  if diff < 60 then return 'たった今' end
  if diff < 3600 then return math.floor(diff / 60) .. '分前' end
  if diff < 86400 then return math.floor(diff / 3600) .. '時間前' end
  if diff < 86400 * 30 then return math.floor(diff / 86400) .. '日前' end
  return math.floor(diff / 86400 / 30) .. 'ヶ月前'
end

--- 使用回数を 3 セルのバーにする。
--- @return string text, integer filled_bytes
local function heat_bar(count)
  local chars = config.options.heat_chars
  local level = count <= 0 and 0 or count <= 2 and 1 or count <= 8 and 2 or 3
  local filled = string.rep(chars.filled, level)
  return filled .. string.rep(chars.empty, 3 - level), #filled
end

local function sort_label()
  for _, s in ipairs(SORTS) do
    if s.key == state.sort then return s.label end
  end
  return state.sort
end

--------------------------------------------------------------------------------
-- レイアウト
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- herdr 連携
--------------------------------------------------------------------------------

-- herdr-notepad は 10 行程度の分割ペインで nvim を開く。ピッカーの間だけタブを
-- ズームして広い画面を借り、閉じるときに戻す。
local herdr = {}

--- @return string? pane_id
function herdr.pane_id()
  local id = vim.env.HERDR_PANE_ID
  if vim.env.HERDR_ENV ~= '1' or not id or id == '' then return nil end
  if vim.fn.executable('herdr') == 0 then return nil end
  return id
end

--- ローカルの unix socket 越しなので同期で待つ。
--- --current はサーバー側のフォーカス中ペインを指してしまうため、必ず ID を渡す。
--- @return table? zoom_result
local function zoom_pane(pane, on)
  local cmd = { 'herdr', 'pane', 'zoom', pane, on and '--on' or '--off' }
  local ok, result = pcall(function() return vim.system(cmd, { text = true }):wait(2000) end)
  if not ok or result.code ~= 0 then return nil end
  local decoded_ok, decoded = pcall(vim.json.decode, result.stdout or '')
  if not decoded_ok or type(decoded) ~= 'table' then return nil end
  return vim.tbl_get(decoded, 'result', 'zoom')
end

--- @return boolean zoomed 自分でズームしたか (戻す責任があるか)
function herdr.enter()
  if not config.options.herdr_zoom then return false end
  local pane = herdr.pane_id()
  if not pane then return false end
  local zoom = zoom_pane(pane, true)
  -- 単一ペインのタブや既にズーム済みなら zoom_changed=false。その場合は触らない
  if not zoom or zoom.zoom_changed ~= true then return false end
  local rows, cols = vim.o.lines, vim.o.columns
  vim.wait(500, function() return vim.o.lines ~= rows or vim.o.columns ~= cols end)
  return true
end

function herdr.leave()
  local pane = herdr.pane_id()
  if pane then zoom_pane(pane, false) end
end

-- プロンプト(枠込み 3 行) + リスト/プレビュー(枠込み 5 行) が最低限
local MIN_ROWS = 8
local MIN_COLS = 40

local function editor_rows() return vim.o.lines - vim.o.cmdheight - 1 end

--- 外枠込みの箱を返す。row/col/w/h はすべて枠を含む外形。
local function layout()
  local o = config.options
  local cols = vim.o.columns
  local rows = editor_rows()
  local w = math.min(math.max(58, math.floor(cols * o.width)), 140, cols - 2)
  local h = math.min(math.max(13, math.floor(rows * o.height)), 34, rows)
  local row = math.max(0, math.floor((rows - h) / 2))
  local col = math.max(0, math.floor((cols - w) / 2))
  local list_w = math.max(10, math.min(math.max(26, math.floor(w * o.list_ratio)), w - 24))
  -- ヘルプ 1 行を出す余裕が無ければリスト側へ回す
  local body_h = h - 3 - 1
  local help = true
  if body_h < 5 then
    body_h = h - 3
    help = false
  end
  return {
    prompt = { row = row, col = col, w = w, h = 3, border = true },
    list = { row = row + 3, col = col, w = list_w, h = body_h, border = true },
    preview = { row = row + 3, col = col + list_w, w = w - list_w, h = body_h, border = true },
    help = { row = row + 3 + body_h, col = col + 2, w = w - 4, h = 1, border = false, hide = not help },
  }
end

-- 枠付きフロートの row/col は枠の左上を指し、width/height は枠の内側を指す
local function win_config(box, extra)
  local pad = box.border and 1 or 0
  local cfg = {
    relative = 'editor',
    row = box.row,
    col = box.col,
    width = math.max(1, box.w - pad * 2),
    height = math.max(1, box.h - pad * 2),
    hide = box.hide == true,
    zindex = 60,
  }
  if box.border then cfg.border = 'rounded' end
  return vim.tbl_extend('force', cfg, extra or {})
end

--- 枠 (位置・タイトル・フッター) を貼り直す。
--- nvim_win_set_config は渡さなかったキーを既定値へ戻すため、毎回全部渡す。
local function set_frame(name, title, footer)
  local win = state.wins[name]
  if not vim.api.nvim_win_is_valid(win) then return end
  local box = state.boxes[name]
  local extra = {}
  if title then
    extra.title = title
    extra.title_pos = 'left'
  end
  if footer then
    extra.footer = footer
    extra.footer_pos = 'right'
  end
  vim.api.nvim_win_set_config(win, win_config(box, extra))
end

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

--------------------------------------------------------------------------------
-- 絞り込みと並び替え
--------------------------------------------------------------------------------

local function comparator()
  if state.sort == 'name' then
    return function(a, b) return a.key < b.key end
  end
  if state.sort == 'recent' then
    return function(a, b)
      if a.mtime ~= b.mtime then return a.mtime > b.mtime end
      return a.key < b.key
    end
  end
  return function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    if a.last ~= b.last then return a.last > b.last end
    return a.key < b.key
  end
end

--- @return SnipdeckEntry[]
local function build_view()
  local query = vim.trim(state.query)
  local items = state.items

  if query == '' or #items == 0 then
    local sorted = vim.list_extend({}, items)
    table.sort(sorted, comparator())
    return vim.tbl_map(function(item) return { item = item, score = 0 } end, sorted)
  end

  local pool = {}
  for i, item in ipairs(items) do
    pool[i] = { idx = i, key = item.key }
  end
  local result = vim.fn.matchfuzzypos(pool, query, { key = 'key' })
  local matched, positions, scores = result[1], result[2], result[3]

  local named, seen = {}, {}
  for n, m in ipairs(matched) do
    local idx = tonumber(m.idx)
    local item = items[idx]
    seen[idx] = true
    -- matchfuzzypos のスコアは数千のスケールで、同程度の一致どうしの差は数十しか出ない。
    -- 使用回数の加点を最大 500 に抑えると、拮抗した候補だけがよく使う方へ入れ替わる。
    local score = (tonumber(scores[n]) or 0) + math.min(item.count, 20) * 25
    table.insert(named, { item = item, pos = positions[n], score = score })
  end
  table.sort(named, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.item.count ~= b.item.count then return a.item.count > b.item.count end
    return a.item.key < b.item.key
  end)

  -- 名前で当たらなかったものは本文検索へ回す。ソート順は通常時と同じ
  local grepped = {}
  local needle = query:lower()
  for i, item in ipairs(items) do
    if not seen[i] then
      for _, line in ipairs(item.lines) do
        if line:lower():find(needle, 1, true) then
          table.insert(grepped, item)
          break
        end
      end
    end
  end
  table.sort(grepped, comparator())

  local view = named
  for _, item in ipairs(grepped) do
    table.insert(view, { item = item, score = -1, grep = true })
  end
  return view
end

--------------------------------------------------------------------------------
-- 描画
--------------------------------------------------------------------------------

local function current() return state.view[state.sel] end

local function render_prompt_marker()
  vim.api.nvim_buf_set_extmark(state.bufs.prompt, ns, 0, 0, {
    id = 1,
    virt_text = { { ' ' .. ICON.prompt .. ' ', 'SnipdeckPrompt' } },
    virt_text_pos = 'inline',
    right_gravity = false,
  })
end

local function render_frame()
  local total = #state.items
  local shown = #state.view
  local pos = shown == 0 and 0 or state.sel
  local meta = shown == total and string.format(' %d/%d · %s ', pos, total, sort_label())
    or string.format(' %d/%d (全 %d) · %s ', pos, shown, total, sort_label())
  set_frame('prompt', {
    { ' ' .. ICON.title .. ' ', 'SnipdeckTitle' },
    { 'Snipdeck ', 'SnipdeckTitle' },
  }, { { meta, 'SnipdeckMeta' } })
end

local function render_list()
  local inner_w = math.max(1, state.boxes.list.w - 2)
  local lines, marks = {}, {}

  if #state.view == 0 then
    local message = #state.items == 0 and '  スニペットがありません'
      or '  一致するスニペットがありません'
    lines = { message }
    marks = { { 0, { { 'SnipdeckEmpty', 0, #message } } } }
  else
    for i, entry in ipairs(state.view) do
      local item = entry.item
      local selected = i == state.sel
      local bar, filled = heat_bar(item.count)
      local count_text = item.count > 0 and tostring(item.count) or ''
      local badge = entry.grep and (ICON.grep .. ' ') or ''

      local prefix = (selected and '▎' or ' ') .. ' ' .. ICON.item .. ' '
      local right_w = dw(bar) + 1 + 3
      local name = truncate(item.key, math.max(1, inner_w - dw(prefix) - dw(badge) - right_w - 1))
      -- 切り詰めがディレクトリ部分に食い込んだときは分けて色付けしない
      local dir = name:sub(1, #item.dir) == item.dir and item.dir or ''
      local gap = math.max(1, inner_w - dw(prefix) - dw(name) - dw(badge) - right_w)

      local segs = {
        { selected and '▎' or ' ', selected and 'SnipdeckMark' or nil },
        { ' ' },
        { ICON.item .. ' ', 'SnipdeckIcon' },
        { dir, 'SnipdeckDir' },
        { name:sub(#dir + 1) },
        { string.rep(' ', gap) },
        { badge, entry.grep and 'SnipdeckBadge' or nil },
        { bar:sub(1, filled), 'SnipdeckHeat' },
        { bar:sub(filled + 1), 'SnipdeckHeatDim' },
        { ' ' .. string.format('%3s', count_text), 'SnipdeckCount' },
      }
      local text, hls, offsets = flatten(segs)

      if entry.pos then
        local base = offsets[4]
        for _, p in ipairs(entry.pos) do
          local from = vim.fn.byteidx(name, tonumber(p))
          local to = vim.fn.byteidx(name, tonumber(p) + 1)
          if from >= 0 and to > from then table.insert(hls, { 'SnipdeckMatch', base + from, base + to, 200 }) end
        end
      end

      table.insert(lines, text)
      table.insert(marks, { i - 1, hls })
    end
  end

  set_lines(state.bufs.list, lines)
  vim.api.nvim_buf_clear_namespace(state.bufs.list, ns, 0, -1)
  for _, entry in ipairs(marks) do
    for _, hl in ipairs(entry[2]) do
      vim.api.nvim_buf_set_extmark(state.bufs.list, ns, entry[1], hl[2], {
        end_col = hl[3],
        hl_group = hl[1],
        priority = hl[4] or 110,
      })
    end
  end

  local win = state.wins.list
  if vim.api.nvim_win_is_valid(win) then
    local row = math.min(math.max(state.sel, 1), math.max(#lines, 1))
    -- 非アクティブなウィンドウでも表示範囲を追従させるため win_call 越しに動かす
    vim.api.nvim_win_call(win, function() pcall(vim.api.nvim_win_set_cursor, win, { row, 0 }) end)
  end
  set_frame('list', { { ' スニペット ', 'SnipdeckTitle' } })
end

local function render_preview()
  local entry = current()
  local buf = state.bufs.preview
  if not entry then
    set_lines(buf, {})
    vim.bo[buf].filetype = ''
    set_frame('preview', { { ' プレビュー ', 'SnipdeckTitle' } })
    return
  end

  local item = entry.item
  set_lines(buf, item.lines)
  local ft = vim.filetype.match({ filename = item.name }) or 'markdown'
  -- .txt は filetype 無しになるが、プロンプトは markdown 寄りなので markdown で色付けする
  if ft == 'text' or ft == '' then ft = 'markdown' end
  if vim.bo[buf].filetype ~= ft then vim.bo[buf].filetype = ft end

  local win = state.wins.preview
  if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_call(win, function() vim.cmd('normal! gg') end) end

  local usage = item.count > 0 and string.format('%d回 · %s', item.count, ago(item.last)) or '未使用'
  local inner_w = math.max(8, state.boxes.preview.w - 2)
  set_frame(
    'preview',
    { { ' ' .. truncate(item.rel, inner_w - 8) .. ' ', 'SnipdeckTitle' } },
    { { string.format(' %d 行 · %s · %s ', #item.lines, pretty_bytes(item.bytes), usage), 'SnipdeckMeta' } }
  )
end

local function render_help()
  if state.boxes.help.hide then return end
  local width = state.boxes.help.w
  local segs, used = {}, 0
  for _, hint in ipairs(HELP) do
    local piece = hint[1] .. ' ' .. hint[2]
    if used + dw(piece) + 2 > width then break end
    if #segs > 0 then
      table.insert(segs, { '  ' })
      used = used + 2
    end
    table.insert(segs, { hint[1], 'SnipdeckHelpKey' })
    table.insert(segs, { ' ' .. hint[2], 'SnipdeckHelpDesc' })
    used = used + dw(piece)
  end
  local text, hls = flatten(segs)
  set_lines(state.bufs.help, { text })
  vim.api.nvim_buf_clear_namespace(state.bufs.help, ns, 0, -1)
  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_set_extmark(state.bufs.help, ns, 0, hl[2], { end_col = hl[3], hl_group = hl[1] })
  end
end

local function render()
  render_frame()
  render_list()
  render_preview()
  render_help()
  render_prompt_marker()
end

--- 絞り込みをやり直して選択位置を保てる範囲で維持する。
local function refresh(keep_rel)
  state.view = build_view()
  if keep_rel then
    for i, entry in ipairs(state.view) do
      if entry.item.rel == keep_rel then
        state.sel = i
        break
      end
    end
  end
  state.sel = math.min(math.max(state.sel, 1), math.max(#state.view, 1))
  render()
end

--------------------------------------------------------------------------------
-- 操作
--------------------------------------------------------------------------------

local function close()
  if not state or state.closing then return end
  state.closing = true
  local source = state.source
  local wins, bufs, aug = state.wins, state.bufs, state.augroup
  local zoomed = state.zoomed
  state = nil

  pcall(vim.api.nvim_del_augroup_by_id, aug)
  if vim.fn.mode():find('i') then vim.cmd('stopinsert') end
  for _, win in pairs(wins) do
    if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
  end
  for _, buf in pairs(bufs) do
    if vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  end
  if source and vim.api.nvim_win_is_valid(source.win) then pcall(vim.api.nvim_set_current_win, source.win) end
  -- ペインが縮む前にフロートを片付けておく
  if zoomed then herdr.leave() end
end

M.close = close

local function move(delta)
  if #state.view == 0 then return end
  local sel = state.sel + delta
  if sel < 1 then sel = #state.view end
  if sel > #state.view then sel = 1 end
  state.sel = sel
  render_frame()
  render_list()
  render_preview()
end

local function cycle_sort()
  local index = 1
  for i, s in ipairs(SORTS) do
    if s.key == state.sort then index = i end
  end
  state.sort = SORTS[index % #SORTS + 1].key
  local keep = current() and current().item.rel or nil
  refresh(keep)
end

local function scroll_preview(keys)
  local win = state.wins.preview
  if not vim.api.nvim_win_is_valid(win) then return end
  vim.api.nvim_win_call(win, function() vim.cmd('normal! ' .. vim.keycode(keys)) end)
end

--- 選択中のスニペットを元のバッファへ反映する。
--- @param mode 'insert'|'append'|'replace'|'yank'
local function apply(mode)
  local entry = current()
  if not entry then return end
  local item = entry.item
  local lines = item.lines
  local source = state.source
  close()

  if mode == 'yank' then
    local text = table.concat(lines, '\n')
    vim.fn.setreg('"', text, 'l')
    vim.fn.setreg('+', text, 'l')
    store.record(item.rel)
    vim.notify(item.key .. ' をヤンクしました', vim.log.levels.INFO, { title = 'Snipdeck' })
    return
  end

  if not vim.api.nvim_buf_is_valid(source.buf) then
    vim.notify('挿入先のバッファがありません', vim.log.levels.WARN, { title = 'Snipdeck' })
    return
  end
  if not vim.bo[source.buf].modifiable then
    vim.notify('挿入先のバッファは変更できません', vim.log.levels.WARN, { title = 'Snipdeck' })
    return
  end
  if vim.api.nvim_win_is_valid(source.win) then vim.api.nvim_set_current_win(source.win) end

  local buf = source.buf
  local was_empty = vim.api.nvim_buf_line_count(buf) == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ''

  if mode == 'replace' or (was_empty and mode ~= 'insert') then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  elseif mode == 'append' then
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  else
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ''
    if line == '' then
      vim.api.nvim_buf_set_lines(buf, row - 1, row, false, lines)
    else
      -- 書きかけの行に続けて差し込めるよう文字単位で put する
      vim.api.nvim_put(lines, 'c', true, true)
    end
  end

  if mode ~= 'insert' then
    local last = vim.api.nvim_buf_line_count(buf)
    pcall(vim.api.nvim_win_set_cursor, 0, { last, 0 })
  end
  store.record(item.rel)
  vim.notify(item.key .. ' を挿入しました', vim.log.levels.INFO, { title = 'Snipdeck' })
end

local function edit()
  local entry = current()
  if not entry then return end
  local path = entry.item.path
  local source = state.source
  close()
  if vim.api.nvim_win_is_valid(source.win) then vim.api.nvim_set_current_win(source.win) end
  vim.cmd.edit(vim.fn.fnameescape(path))
end

--- 削除の確認。差し替えれば別の UI にもできる。
--- @param message string
--- @return boolean
function M.confirm(message) return vim.fn.confirm(message, '&Yes\n&No', 2, 'Question') == 1 end

local function delete()
  local entry = current()
  if not entry then return end
  local item = entry.item
  state.modal = true
  local ok = M.confirm(item.rel .. ' を削除しますか?')
  state.modal = false
  if not ok or not state then return end
  if not store.delete(item) then
    vim.notify(item.rel .. ' を削除できませんでした', vim.log.levels.ERROR, { title = 'Snipdeck' })
    return
  end
  state.items = store.items()
  refresh()
  vim.notify(item.rel .. ' を削除しました', vim.log.levels.INFO, { title = 'Snipdeck' })
end

--------------------------------------------------------------------------------
-- 起動
--------------------------------------------------------------------------------

local function make_buf(name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].swapfile = false
  vim.b[buf].snipdeck = name
  return buf
end

local WINHL = table.concat({
  'Normal:SnipdeckNormal',
  'NormalNC:SnipdeckNormal',
  'FloatBorder:SnipdeckBorder',
  'FloatTitle:SnipdeckTitle',
  'FloatFooter:SnipdeckMeta',
  'CursorLine:SnipdeckSelection',
  'EndOfBuffer:SnipdeckNormal',
}, ',')

local function open_windows()
  state.boxes = layout()
  local order = { 'prompt', 'list', 'preview', 'help' }
  for _, name in ipairs(order) do
    local buf = make_buf(name)
    local win = vim.api.nvim_open_win(buf, false, win_config(state.boxes[name], { style = 'minimal' }))
    state.bufs[name] = buf
    state.wins[name] = win
    local wo = vim.wo[win]
    wo.winhighlight = WINHL
    wo.wrap = name == 'preview'
    wo.cursorline = name == 'list'
  end

  local preview = vim.wo[state.wins.preview]
  preview.linebreak = true
  preview.breakindent = true
  vim.wo[state.wins.list].cursorlineopt = 'line'
  vim.bo[state.bufs.prompt].modifiable = true
end

local function relayout()
  state.boxes = layout()
  for name in pairs(state.wins) do
    set_frame(name)
  end
  render()
end

local function map(lhs, fn, modes)
  vim.keymap.set(modes or { 'i', 'n' }, lhs, fn, {
    buffer = state.bufs.prompt,
    nowait = true,
    silent = true,
    desc = 'Snipdeck',
  })
end

local function setup_keymaps()
  map('<CR>', function() apply('insert') end)
  map('<C-a>', function() apply('append') end)
  map('<C-r>', function() apply('replace') end)
  map('<C-y>', function() apply('yank') end)
  map('<C-e>', edit)
  map('<C-x>', delete)
  map('<C-g>', cycle_sort)
  map('<C-f>', function() scroll_preview('<C-d>') end)
  map('<C-b>', function() scroll_preview('<C-u>') end)
  -- 大西配列の物理 J/K は t/n を送る (configs/onishi-nav.lua と同じ割り当て)
  map('<C-t>', function() move(1) end)
  map('<C-n>', function() move(-1) end)
  map('<Tab>', function() move(1) end)
  map('<S-Tab>', function() move(-1) end)
  map('<Down>', function() move(1) end)
  map('<Up>', function() move(-1) end)
  map('<C-d>', function() move(5) end)
  map('<C-u>', function() move(-5) end)
  map('<Esc>', close)
  map('<C-c>', close)
  map('q', close, 'n')
end

local function setup_autocmds()
  state.augroup = vim.api.nvim_create_augroup('snipdeck-session', { clear = true })
  local prompt_buf = state.bufs.prompt

  vim.api.nvim_buf_attach(prompt_buf, false, {
    on_lines = function()
      vim.schedule(function()
        if not state or state.bufs.prompt ~= prompt_buf then return end
        local line = vim.api.nvim_buf_get_lines(prompt_buf, 0, 1, false)[1] or ''
        if line == state.query then return end
        state.query = line
        state.sel = 1
        refresh()
      end)
    end,
  })

  for _, win in pairs(state.wins) do
    vim.api.nvim_create_autocmd('WinClosed', {
      group = state.augroup,
      pattern = tostring(win),
      callback = close,
    })
  end

  vim.api.nvim_create_autocmd('BufLeave', {
    group = state.augroup,
    buffer = prompt_buf,
    callback = function()
      if state and not state.modal then close() end
    end,
  })

  vim.api.nvim_create_autocmd('VimResized', {
    group = state.augroup,
    callback = function()
      if state then relayout() end
    end,
  })

  -- :qa! などで close() を通らずに終わるとペインがズームしたまま残る
  vim.api.nvim_create_autocmd('VimLeavePre', { group = state.augroup, callback = close })
end

function M.open()
  if state then
    if vim.api.nvim_win_is_valid(state.wins.prompt) then
      vim.api.nvim_set_current_win(state.wins.prompt)
      return
    end
    close()
  end

  local zoomed = herdr.enter()

  if editor_rows() < MIN_ROWS or vim.o.columns < MIN_COLS then
    if zoomed then herdr.leave() end
    vim.notify(
      ('ウィンドウが小さすぎます (%d 行 %d 桁以上が必要)'):format(MIN_ROWS + 2, MIN_COLS),
      vim.log.levels.WARN,
      { title = 'Snipdeck' }
    )
    return
  end

  local root = config.dir()
  setup_highlights()

  state = {
    zoomed = zoomed,
    items = store.items(),
    view = {},
    sel = 1,
    query = '',
    sort = config.options.sort,
    wins = {},
    bufs = {},
    boxes = {},
    source = { win = vim.api.nvim_get_current_win(), buf = vim.api.nvim_get_current_buf() },
  }

  open_windows()
  setup_keymaps()
  setup_autocmds()
  refresh()

  vim.api.nvim_set_current_win(state.wins.prompt)
  vim.cmd('startinsert')

  if vim.fn.isdirectory(root) == 0 then
    vim.notify(
      root .. ' がありません。:SnipdeckSave で作成できます',
      vim.log.levels.WARN,
      { title = 'Snipdeck' }
    )
  end
end

--- テスト用の内部状態アクセサ
function M._state() return state end

return M
