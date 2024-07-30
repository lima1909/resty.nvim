vim.filetype.add({ extension = { http = "http" } })

vim.keymap.set("n", "zz", function()
	-- toggle folding
	if vim.opt.foldmethod._value ~= "expr" then
		vim.cmd("setlocal foldmethod=expr")
		vim.cmd("setlocal foldexpr=v:lua.foldexpr(v:lnum)")
	else
		vim.cmd("setlocal foldmethod=manual")
		vim.cmd("normal zE")
	end

	-- vim.cmd("setlocal foldtext=~~~")
end, { silent = true, desc = "[zz] activate folding" })

vim.keymap.set("n", "+", "zo")
vim.keymap.set("n", "-", "zc")
