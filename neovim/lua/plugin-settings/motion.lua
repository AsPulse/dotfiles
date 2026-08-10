--- @type LazyPluginSpec[]
return {
  {
    'ggandor/lightspeed.nvim',
    event = 'BufEnter *.*',
    init = function()
      -- 既定マップは s/S と t/T を取るが、大西配列ではそこに移動 (右/下) が
      -- 来る。読み込み順で潰し合うのを避けるため既定を全部止め、必要な分だけ
      -- config で張り直す。
      vim.g.lightspeed_no_default_keymaps = true
    end,
    config = function()
      local function map(mode, lhs, rhs) vim.keymap.set(mode, lhs, rhs, { silent = true }) end

      -- 旧 s (omni)。移動が s を使うので、空いた h へ
      map('n', 'h', '<Plug>Lightspeed_omni_s')
      map('x', 'h', '<Plug>Lightspeed_s')
      map('o', 'z', '<Plug>Lightspeed_s')

      -- 旧 t / T。移動が t を使うので、空いた l / L へ
      map({ 'n', 'x', 'o' }, 'l', '<Plug>Lightspeed_t')
      map({ 'n', 'x', 'o' }, 'L', '<Plug>Lightspeed_T')

      -- 以下は移動と衝突しないので既定のまま
      map({ 'n', 'x', 'o' }, 'f', '<Plug>Lightspeed_f')
      map({ 'n', 'x', 'o' }, 'F', '<Plug>Lightspeed_F')
      map({ 'n', 'x', 'o' }, ';', '<Plug>Lightspeed_;_ft')
      map({ 'n', 'x', 'o' }, ',', '<Plug>Lightspeed_,_ft')
      map('n', 'gs', '<Plug>Lightspeed_gs')
      map('n', 'gS', '<Plug>Lightspeed_gS')
      map('o', 'x', '<Plug>Lightspeed_x')
      map('o', 'X', '<Plug>Lightspeed_X')
    end,
  },
}
