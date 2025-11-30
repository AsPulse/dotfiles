local opt = vim.opt
local wo  = vim.wo

opt.encoding = 'utf-8'
opt.autoread = true
opt.swapfile = false
opt.ignorecase = true
opt.incsearch = true
opt.termguicolors = true
opt.background = 'dark'
opt.wildmenu = true
opt.wildmode = 'list:longest'
opt.pumblend = 10
opt.splitright = true
opt.splitbelow = true

wo.number = true
wo.relativenumber = true
wo.cursorline = true
wo.signcolumn = 'yes:1'

vim.g.mapleader = ' '

return nil
