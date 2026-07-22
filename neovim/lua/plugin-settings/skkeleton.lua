--- @type LazyPluginSpec[]
return {
  {
    'vim-skk/skkeleton',
    event = { 'InsertEnter', 'CmdlineEnter', 'TermEnter' },
    dependencies = { 'vim-denops/denops.vim', 'yuki-yano/denops-lazy.nvim' },
    config = function()
      require('denops-lazy').load('skkeleton', { wait_load = false })
      -- 大西配列テーブルは rom を継がない新規テーブルとして登録する。
      -- rom に merge すると QWERTY 前提のデフォルトルールが残り、
      -- 大西写像後の打鍵と誤マッチするため。
      vim.api.nvim_create_autocmd('User', {
        pattern = 'skkeleton-initialize-pre',
        callback = function()
          local path = vim.fn.expand('~/.skk/kana-rule-onishi.json')
          local rules = vim.json.decode(table.concat(vim.fn.readfile(path), ''))
          -- SKK 機能キー: 直接入力トグルは大西の L (物理 W)、q はカタカナのまま。
          -- abbrev と sticky shift は使わないので割り当てない。
          -- Space の変換開始もかなテーブル側の担当 (vim-skk/skkeleton#183)。
          rules[' '] = 'henkanFirst'
          rules['w'] = 'disable'
          rules['W'] = 'zenkaku'
          rules['q'] = 'katakana'
          vim.fn['skkeleton#register_kanatable']('onishi', rules, true)
          vim.fn['skkeleton#config']({ kanaTable = 'onishi' })
        end,
      })
      vim.fn['skkeleton#config']({
        debug = false,
        eggLikeNewline = true,
        globalDictionaries = {
          '~/.skk/SKK-JISYO.L',
        },
        -- 大西で記号キー位置に来る M J B H の行でも Shift で変換開始
        -- できるようにする (US 配列)
        lowercaseMap = {
          ['<'] = ',',
          ['>'] = '.',
          [':'] = ';',
          ['?'] = '/',
        },
        userDictionary = '~/.skk/skkeleton.txt',
      })
      vim.keymap.set({ 'i', 't' }, '<C-j>', '<Plug>(skkeleton-enable)', { remap = true })
      vim.keymap.set({ 'i', 't' }, 'w', function()
        if vim.fn['skkeleton#is_enabled']() == 1 then
          return '<Plug>(skkeleton-disable)'
        else
          return 'w'
        end
      end, { expr = true, remap = true })
      vim.fn['skkeleton#register_keymap']('henkan', 'q', 'katakana')
      vim.fn['skkeleton#register_keymap']('henkan', '<C-q>', 'hankatakana')
    end,
  },
  {
    'delphinus/skkeleton_indicator.nvim',
    event = { 'InsertEnter', 'CmdlineEnter', 'TermEnter' },
    opts = {},
  },
}
