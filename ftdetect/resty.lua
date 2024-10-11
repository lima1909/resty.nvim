local parser = require("resty.parser.parserng")
local result = require("resty.parser.result")

vim.filetype.add({ extension = { resty = "resty" } })

vim.api.nvim_set_hl(0, "HintReplace", { fg = "DarkGrey" })
vim.fn.sign_define("HintMarker", { text = "→", texthl = "WarningMsg", numhl = "WarningMsg" })

local hintID = 7
local hintNS = vim.api.nvim_create_namespace("resty_hint")

vim.api.nvim_create_autocmd("CursorMoved", {
	pattern = "*.resty",
	callback = function()
		local bufNr = vim.api.nvim_get_current_buf()

		-- removes all hints and signs
		vim.api.nvim_buf_clear_namespace(bufNr, hintNS, 0, -1)
		vim.fn.sign_unplace("", { id = hintID, buffer = bufNr })

		local cursor = vim.api.nvim_win_get_cursor(0)
		local row, col = cursor[1], cursor[2]

		local lines = vim.api.nvim_buf_get_lines(bufNr, 0, -1, true)
		local current_line = lines[row]

		local key = nil
		for s, k, e in string.gmatch(current_line, "(){{(.-)}}()") do
			if s - 1 <= col and e - 1 > col then
				key = k
				break
			end
		end

		if key then
			local r = parser.parse(lines, row)
			local value = r.variables[key]

			-- resolve env variables and exec
			if not value then
				value = r:replace_variable_key(key)
			end

			if value then
				local lnum_str = ""
				-- env or exec variables have no line number
				local lnum = r.meta.variables[key]
				if lnum then
					vim.fn.sign_place(hintID, "", "HintMarker", bufNr, { lnum = lnum, priority = 10 })
					lnum_str = "[" .. lnum .. "] "
				end

				vim.api.nvim_buf_set_extmark(bufNr, hintNS, row - 1, col, {
					virt_text = { { lnum_str .. key .. " = " .. value, "HintReplace" } },
				})
			else
				vim.api.nvim_buf_set_extmark(bufNr, hintNS, row - 1, col, {
					virt_text = { { "no value found for: " .. key, "HintReplace" } },
				})
			end
		end
	end,
})
