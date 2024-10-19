local util = require("resty.util")

local M = {}

-- TODO: is this a good idea to cache the bufnr?
M.get_current_bufnr = function(bufnr)
	-- override the existing bufnr
	if bufnr then
		M.current_bufnr = bufnr
	-- first time, set the bufnr
	elseif M.current_bufnr == nil then
		M.current_bufnr = vim.api.nvim_get_current_buf()
	end

	return M.current_bufnr
end

M.find_favorite = function(input, favorite)
	local row

	M._check_lines(input, function(r, f)
		if favorite == f then
			row = r
			return true -- founded and break
		else
			return false
		end
	end)

	return row
end

M.find_all_favorites = function(input)
	local favorites = {}

	M._check_lines(input, function(r, f)
		table.insert(favorites, { ["row"] = r, ["favorite"] = f })
		return false
	end)

	return favorites
end

M.find_favorite_by_prefix = function(input, prefix)
	local favorites = {}

	M._check_lines(input, function(_, f)
		if vim.startswith(f, prefix) then
			table.insert(favorites, f)
		end

		return false
	end)

	return favorites
end

M._check_lines = function(input, check)
	local lines = util.input_to_lines(input)

	for row, l in ipairs(lines) do
		if vim.startswith(l, "###") then
			l = l:sub(4)
			local pos = string.find(l, "#")
			if pos then
				local favorite = l:sub(pos + 1)
				-- favorite = vim.trim(favorite)
				if check(row, favorite) == true then
					return
				end
			end
		end
	end
end

return M
