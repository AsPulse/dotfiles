-- 大西配列でも hjkl の移動を「物理位置」に保つ。
-- 物理 H J K L が送る文字は k t n s なので、そこへ移動を割り当て直す。
--
-- 押し出される t(till) n(次の検索) s(lightspeed) は、移動が抜けて空いた
-- h j l へ退避する。lightspeed 系は plugin-settings/motion.lua が張る。
local function map(mode, lhs, rhs) vim.keymap.set(mode, lhs, rhs, { silent = true }) end

-- 移動 (演算子待機も含めないと dt / dn などが壊れる)
map({ 'n', 'x', 'o' }, 'k', 'h')
map({ 'n', 'x', 'o' }, 't', 'j')
map({ 'n', 'x', 'o' }, 'n', 'k')
map({ 'n', 'x', 'o' }, 's', 'l')

-- 検索の次候補/前候補。n は移動に取られたので j と H へ
map({ 'n', 'x' }, 'j', 'n')
map({ 'n', 'x' }, 'H', 'N')

-- J(行連結) は物理位置を保って T へ
map({ 'n', 'x' }, 'T', 'J')
