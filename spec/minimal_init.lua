local plenary_dir = "/tmp/plenary.nvim"

if vim.fn.isdirectory(plenary_dir) == 0 then
	vim.fn.system({
		"git",
		"clone",
		"--depth",
		"1",
		"https://github.com/nvim-lua/plenary.nvim",
		plenary_dir,
	})
end

vim.opt.rtp:append(".")
vim.opt.rtp:append(plenary_dir)

vim.cmd.runtime({ "plugin/plenary.vim", bang = true })
require("plenary.busted")
