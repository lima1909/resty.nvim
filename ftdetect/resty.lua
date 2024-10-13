vim.filetype.add({ extension = { resty = "resty" } })
vim.diagnostic.config({ update_in_insert = true })

local ns_diagnostics = vim.api.nvim_create_namespace("resty_diagnostics")
local parser = require("resty.parser.parserng")

vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
	pattern = { "*.resty" },
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()
		vim.diagnostic.reset(ns_diagnostics, bufnr)

		local parsed = parser.parse(
			vim.api.nvim_buf_get_lines(bufnr, 0, -1, true),
			vim.api.nvim_win_get_cursor(0)[1],
			{ is_prompt_supported = false }
		)
		if parsed:has_diag() then
			vim.diagnostic.set(ns_diagnostics, bufnr, parsed.diagnostics)
		end
	end,
})

vim.api.nvim_set_hl(0, "HintReplace", { fg = "LightYellow" })
vim.fn.sign_define("HintMarker", { text = "→", texthl = "WarningMsg", numhl = "WarningMsg" })

local hintID = 7
local hintNS = vim.api.nvim_create_namespace("resty_hint")

vim.api.nvim_create_autocmd("CursorMoved", {
	pattern = { "*.resty", "*.http" },
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()

		-- removes all hints and signs
		vim.api.nvim_buf_clear_namespace(bufnr, hintNS, 0, -1)
		vim.fn.sign_unplace("", { id = hintID, buffer = bufnr })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
		local cursor = vim.api.nvim_win_get_cursor(0)
		local row, col = cursor[1], cursor[2]

		local text, lnum = parser.get_replace_variable_str(lines, row, col)
		if not text then
			return
		end

		vim.api.nvim_buf_set_extmark(bufnr, hintNS, row - 1, col, { virt_text = { { text, "HintReplace" } } })
		if lnum then
			vim.fn.sign_place(hintID, "", "HintMarker", bufnr, { lnum = lnum, priority = 10 })
		end
	end,
})
