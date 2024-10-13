local parser = require("resty.parser.parserng")

vim.filetype.add({ extension = { resty = "resty" } })

vim.api.nvim_set_hl(0, "HintReplace", { fg = "LightYellow" })
vim.fn.sign_define("HintMarker", { text = "→", texthl = "WarningMsg", numhl = "WarningMsg" })

local hintID = 7
local hintNS = vim.api.nvim_create_namespace("resty_hint")

vim.api.nvim_create_autocmd("CursorMoved", {
	pattern = "*.resty",
	callback = function()
		local bufNr = vim.api.nvim_get_current_buf()
		local cursor = vim.api.nvim_win_get_cursor(0)
		local row, col = cursor[1], cursor[2]
		local bufRow = row - 1

		-- removes all hints and signs
		vim.api.nvim_buf_clear_namespace(bufNr, hintNS, 0, -1)
		vim.fn.sign_unplace("", { id = hintID, buffer = bufNr })

		local current_line = vim.api.nvim_buf_get_text(bufNr, bufRow, 0, bufRow, 1000, {})[1]
		local key = nil
		for s, k, e in string.gmatch(current_line, "(){{(.-)}}()") do
			if s - 1 <= col and e - 1 > col then
				key = k
				break
			end
		end

		if key then
			local lines = vim.api.nvim_buf_get_lines(bufNr, 0, -1, true)
			local r = parser.parse(lines, row, { is_prompt_supported = false })
			local value = r.variables[key]

			-- resolve environment and exec variable
			if not value then
				value = r:replace_variable_by_key(key)
			end

			if value then
				local lnum_str = ""
				-- environment or exec variables have no line number
				local lnum = r.meta.variables[key]
				if lnum then
					vim.fn.sign_place(hintID, "", "HintMarker", bufNr, { lnum = lnum, priority = 10 })
					lnum_str = "[" .. lnum .. "] "
				end

				vim.api.nvim_buf_set_extmark(bufNr, hintNS, bufRow, col, {
					virt_text = { { lnum_str .. key .. " = " .. value, "HintReplace" } },
				})
			else
				local text = "no value found for: " .. key
				-- don't execute a prompt
				local isPrompt = string.sub(key, 1, 1) == ":"
				if isPrompt == true then
					text = "prompt variables are not supported for a preview"
				end
				vim.api.nvim_buf_set_extmark(bufNr, hintNS, bufRow, col, {
					virt_text = { { text, "HintReplace" } },
				})
			end
		end
	end,
})
