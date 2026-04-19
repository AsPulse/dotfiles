if vim.fn.has('mac') == 1 then
  vim.g.clipboard = {
    name = 'macOS-clipboard',
    copy = {
      ['+'] = 'pbcopy',
      ['*'] = 'pbcopy',
    },
    paste = {
      ['+'] = 'pbpaste',
      ['*'] = 'pbpaste',
    },
  }
else
  -- Remote (SSH/mosh) では OSC 52 でローカルのクリップボードに書き込む。
  -- zellij が termcap query をブロックして自動検出が効かないため明示設定する。
  -- paste は OSC 52 read を発行しない: mosh が端末→ホスト方向の応答を通さず、
  -- 標準実装だと "+p のたびに最大 10 秒ブロックするため、内部キャッシュから返す。
  local osc52 = require('vim.ui.clipboard.osc52')
  local cache = { ['+'] = { {}, 'v' }, ['*'] = { {}, 'v' } }
  local function make_copy(reg)
    local osc_copy = osc52.copy(reg)
    return function(lines, regtype)
      cache[reg] = { lines, regtype }
      osc_copy(lines)
    end
  end
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = {
      ['+'] = make_copy('+'),
      ['*'] = make_copy('*'),
    },
    paste = {
      ['+'] = function() return cache['+'] end,
      ['*'] = function() return cache['*'] end,
    },
  }
end
