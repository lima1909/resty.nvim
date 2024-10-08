local parser = require("resty.parser.parserng")

vim.filetype.add({ extension = { resty = "resty" } })
vim.api.nvim_set_hl(0, "Hint", { fg = "DarkGrey" }) -- "#FFD700" }) -- Custom yellow hint color

local namespace = vim.api.nvim_create_namespace("my_hint")

vim.api.nvim_create_autocmd("CursorMoved", {
	pattern = "*.resty",
	callback = function()
		-- removes all hints
		vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)

		local cursor = vim.api.nvim_win_get_cursor(0)
		local row, col = cursor[1], cursor[2]

		local syn_id = vim.fn.synID(row, col + 1, true)
		local syn_name = vim.fn.synIDattr(syn_id, "name")

		if syn_name == "restyReplace" then
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
			-- TODO: do it async, can need some time
			local parsed = parser.parse(lines, row)

			local var_line = lines[row]
			local var_key = ""
			local c = col + 1
			local s = string.sub(var_line, c, c)
			while c > 0 do
				var_key = s .. var_key
				c = c - 1
				s = string.sub(var_line, c, c)
				if s == "{" then
					break
				end
			end

			c = col + 2
			s = string.sub(var_line, c, c)
			if s ~= "}" then
				while c < #var_line do
					var_key = var_key .. s
					c = c + 1
					s = string.sub(var_line, c, c)
					if s == "}" then
						break
					end
				end
			end

			print(row .. " : " .. col + 1 .. " " .. var_key)

			local var_value = parsed.variables[var_key]
			if var_value then
				vim.api.nvim_buf_set_extmark(0, namespace, row - 1, col + 3, {
					virt_text = { { "'" .. var_key .. "' = " .. var_value, "Hint" } }, -- Text and highlight group
					virt_text_pos = "eol", -- Set position at the end of the line (eol)
				})
			end
		end
	end,
})
