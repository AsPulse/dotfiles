-- 行頭/行末。大西配列の物理位置に合わせて C-h / C-l から C-k / C-s へ。
-- C-s は端末の XOFF に食われることがあるので、効かない場合は stty -ixon を確認する。
vim.keymap.set({ 'n', 'v' }, '<C-k>', '^', { silent = true, remap = true })
vim.keymap.set({ 'n', 'v' }, '<C-s>', '$', { silent = true, remap = true })
