--- @type LazyPluginSpec[]
return {
  {
    'vim-skk/skkeleton',
    event = { 'InsertEnter', 'CmdlineEnter', 'TermEnter' },
    dependencies = { 'vim-denops/denops.vim', 'yuki-yano/denops-lazy.nvim' },
    config = function()
      require('denops-lazy').load('skkeleton', { wait_load = false })
      -- 大西配列テーブルは rom を継がない新規テーブルとして登録する。
      -- rom に merge するとデフォルトのローマ字ルールが残り、
      -- AZIK ベースの打鍵と誤マッチするため。
      vim.api.nvim_create_autocmd('User', {
        pattern = 'skkeleton-initialize-pre',
        callback = function()
          local path = vim.fn.expand('~/.skk/kana-rule-onishi.json')
          local rules = vim.json.decode(table.concat(vim.fn.readfile(path), ''))
          -- SKK 機能キー。大西配列はキーボード側で解決済みなので l/L/q は
          -- 素の SKK と同じ位置に置ける。
          -- abbrev と sticky shift は使わないので割り当てない。
          -- Space の変換開始もかなテーブル側の担当 (vim-skk/skkeleton#183)。
          rules[' '] = 'henkanFirst'
          rules['l'] = 'disable'
          rules['L'] = 'zenkaku'
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
        -- ん は大西配列で ; の位置にあり Shift しても大文字にならないため、
        -- : を ; のシフト入力と見做して送り仮名を開始できるようにする (US 配列)
        lowercaseMap = {
          [':'] = ';',
        },
        userDictionary = '~/.skk/skkeleton.txt',
      })
      vim.keymap.set({ 'i', 't' }, '<C-j>', '<Plug>(skkeleton-enable)', { remap = true })
      vim.keymap.set({ 'i', 't' }, 'l', function()
        if vim.fn['skkeleton#is_enabled']() == 1 then
          return '<Plug>(skkeleton-disable)'
        else
          return 'l'
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
