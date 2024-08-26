local M = {}

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

local function to_lines(input)
	if type(input) == "table" then
		return input
	elseif type(input) == "string" then
		return vim.split(input, "\n")
	else
		error("only string or string array are supported as input. Got: " .. type(input), 0)
	end
end

M.check_lines = function(lines, check)
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

M.find_favorite = function(input, favorite)
	local lines = to_lines(input)
	local row

	M.check_lines(lines, function(r, f)
		if favorite == f then
			row = r
			return true
		else
			return false
		end
	end)

	return row
end

M.find_all_favorites = function(input)
	local lines = to_lines(input)
	local favorites = {}

	M.check_lines(lines, function(r, f)
		table.insert(favorites, { ["row"] = r, ["favorite"] = f })
		return false
	end)

	return favorites
end

M.find_favorite_by_prefix = function(input, prefix)
	local lines = to_lines(input)
	local favorites = M.find_all_favorites(lines)
	local list = {}

	for _, f in pairs(favorites) do
		if vim.startswith(f.favorite, prefix) then
			table.insert(list, f.favorite)
		end
	end

	return list
end

return M
