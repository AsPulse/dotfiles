local M = {}

--- @class SnipdeckOptions
--- @field dir string スニペットを置くディレクトリ
--- @field extensions string[] スニペットとして扱う拡張子
--- @field usage_file string 使用回数の保存先 (マシン固有の状態なので dotfiles には置かない)
--- @field max_lines integer 1 ファイルから読み込む最大行数
--- @field width number 画面幅に対するフロートの比率
--- @field height number 画面高に対するフロートの比率
--- @field list_ratio number フロート幅に対するリストペインの比率
--- @field sort 'freq'|'recent'|'name' 初期ソート順
--- @field herdr_zoom boolean herdr 内なら開いている間だけペインをズームする
--- @field heat_chars { filled: string, empty: string } 使用頻度バーの字形

--- @type SnipdeckOptions
local defaults = {
  dir = '~/snippets',
  extensions = { 'txt', 'md', 'markdown', 'prompt' },
  usage_file = vim.fn.stdpath('data') .. '/snipdeck/usage.json',
  max_lines = 5000,
  width = 0.86,
  height = 0.82,
  list_ratio = 0.36,
  sort = 'freq',
  herdr_zoom = true,
  -- Block Elements。JetBrainsMono Nerd Font に確実にあり、日本語フォントへ
  -- フォールバックして字形が崩れない字を選ぶ
  heat_chars = { filled = '█', empty = '░' },
}

--- @type SnipdeckOptions
M.options = vim.deepcopy(defaults)

--- @param opts SnipdeckOptions?
function M.setup(opts) M.options = vim.tbl_deep_extend('force', M.options, opts or {}) end

function M.dir() return vim.fs.normalize(M.options.dir) end

return M
