require("config.lazy")

if os.getenv("SSH_TTY") then
  vim.g.clipboard = 'osc52'
end
vim.opt.mouse = ""

vim.g.did_indent_on = true   -- stops filetype indent plugins

-- Always use spaces, never tabs
vim.opt.expandtab = true

-- Normal indent width
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2

-- Smart indenting for code
vim.opt.smartindent = true

-- Visually indent wrapped lines
vim.opt.breakindent = true
vim.opt.breakindentopt = { "shift:4" }  -- add 4 spaces on wrapped lines

-- fix autocomplete navigation
vim.opt.wildmode = { "longest:full" }
vim.opt.wildmenu = true
vim.keymap.set('c', '<Down>', '<C-n>')
vim.keymap.set('c', '<Up>', '<C-p>')

-- ctrl up and down for window navigation
vim.keymap.set('n', '<C-Up>', '<C-w>k', { noremap = true, silent = true })
vim.keymap.set('n', '<C-Down>', '<C-w>j', { noremap = true, silent = true })

vim.filetype.add({
  extension = {
    mdx = "markdown",
  },
})

require("darkplus")
vim.cmd.colorscheme "darkplus"

-- Transparent background so terminal/tmux dimming works
vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "NONE" })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE" })
vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "NONE" })

-- require("ibhagwan/fzf-lua")
vim.keymap.set('n', '<C-f>', '<cmd>FzfLua files<CR>', { noremap = true, silent = true })


