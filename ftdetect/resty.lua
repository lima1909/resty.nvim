local parser = require("resty.parser.parserng")
local result = require("resty.parser.result")

vim.filetype.add({ extension = { resty = "resty" } })

vim.api.nvim_set_hl(0, "Hint", { fg = "DarkGrey" })
local hint_ns = vim.api.nvim_create_namespace("resty_hint")

vim.api.nvim_create_autocmd("CursorMoved", {
	pattern = "*.resty",
	callback = function()
		-- removes all hints
		vim.api.nvim_buf_clear_namespace(0, hint_ns, 0, -1)

		local cursor = vim.api.nvim_win_get_cursor(0)
		local row, col = cursor[1], cursor[2]

		local syn_id = vim.fn.synID(row, col + 1, true)
		local syn_name = vim.fn.synIDattr(syn_id, "name")

		if syn_name == "restyReplace" then
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
			local line = lines[row]
			local parsed = parser.parse(lines, row)

			local key = ""
			for s, k, e in string.gmatch(line, "(){{(.-)}}()") do
				if s - 1 <= col and e - 1 >= col then
					key = k
					break
				end
			end

			local c = string.sub(key, 1, 1)
			if c == "$" or c == ">" then
				local r = result.new()
				local value = r:replace_variable("{{" .. key .. "}}", 0)
				vim.api.nvim_buf_set_extmark(0, hint_ns, row - 1, col, {
					virt_text = { { r.replacements[1].type .. ": '" .. key .. "' = " .. value, "Hint" } },
				})
			else
				local value = parsed.variables[key]
				if value then
					vim.api.nvim_buf_set_extmark(0, hint_ns, row - 1, col, {
						virt_text = { { "'" .. key .. "' = " .. value, "Hint" } },
					})
				else
					vim.api.nvim_buf_set_extmark(0, hint_ns, row - 1, col, {
						virt_text = { { "no value found for: '" .. key .. "'", "Hint" } },
					})
				end
			end
		end
	end,
})
