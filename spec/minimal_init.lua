-- git checkout plenary
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

-- git checkout telescope
local telescope_dir = "/tmp/telescope.nvim"
if vim.fn.isdirectory(telescope_dir) == 0 then
	vim.fn.system({
		"git",
		"clone",
		"--depth",
		"1",
		"https://github.com/nvim-telescope/telescope.nvim",
		telescope_dir,
	})
end

vim.opt.rtp:append(".")
vim.opt.rtp:append(plenary_dir)
-- vim.opt.rtp:append(telescope_dir)

vim.cmd.runtime({ "plugin/plenary.vim", bang = true })
-- vim.cmd.runtime({ "plugin/telescope.vim", bang = true })

require("plenary.busted")
-- require("telescope")
