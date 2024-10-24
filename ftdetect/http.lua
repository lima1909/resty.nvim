vim.filetype.add({ extension = { http = "http" } })

--[[
-- Reset diagnostic by changing the file
vim.api.nvim_create_augroup("RestyDiagnostic", { clear = true })
-- text change in Insert and Normal mode => diagnostic reset
vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
	group = "RestyDiagnostic",
	pattern = "*.http",
	callback = function(ev)
		require("resty.diagnostic").reset(ev.buf)
	end,
})
-- text change in Esc and Normal mode => diagnostic on
-- vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
-- 	group = "RestyDiagnostic",
-- 	pattern = "*.http",
-- 	callback = function(ev)
-- 		local winnr = vim.api.nvim_get_current_win()
-- 		local row = vim.api.nvim_win_get_cursor(winnr)[1]
-- 		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
--
-- 		-- local r = require("resty.parser").parse(lines, row)
-- 		local r = require("resty.parser").parse(lines, row)
-- 		require("resty.diagnostic").show(ev.buf, r)
-- 	end,
-- })
-- ]]
