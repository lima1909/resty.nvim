local plenary_dir = "/tmp/plenary.nvim"

if not vim.fn.isdirectory(plenary_dir) then
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
