local M = {}

-- find all 'it' test-functions
M.find_all_it_funcs = function(bufnr)
	bufnr = bufnr or 0

	local parser = vim.treesitter.get_parser(bufnr, "lua")
	local tree = parser:parse()[1]

	-- find all functions @func with the name 'it' (@fname)
	local query =
		vim.treesitter.query.parse("lua", '(function_call name: (identifier) @fname (#eq? @fname "it")) @func')

	local its = {}
	for id, node, _ in query:iter_captures(tree:root(), bufnr) do
		local capture_name = query.captures[id]

		if capture_name == "func" then
			local start_row, _, end_row, _ = node:range()
			-- print("-", "at", start_row, " - ", end_row)
			-- its[start_row] = end_row
			table.insert(its, { start_row, end_row })
		end
	end

	return its
end

M.remove_selected_it_func = function(its, cursor_at)
	for pos, it in ipairs(its) do
		if it[1] <= cursor_at and it[2] >= cursor_at then
			table.remove(its, pos)
			return true
		end
	end

	return false
end

M.comment_it_funcs_out = function(its, lines)
	local comment = "-- "

	for _, it in ipairs(its) do
		local s, e = it[1] + 1, it[2] + 1
		for i = s, e do
			local line = lines[i]
			lines[i] = comment .. line
		end
	end
end

-- returns start and end row for the 'it' test-function at the cursor,
-- or nil, it is not a 'it' function
-- local ts_utils = require("nvim-treesitter.ts_utils")
-- M.get_it_func_rows_at_cursor = function()
-- 	local node = ts_utils.get_node_at_cursor()
--
-- 	-- Traverse up the syntax tree to find the function node
-- 	while node do
-- 		if node:type() == "function_call" then
-- 			-- TODO: check the name (ident) of the child node is 'it'
-- 			break
-- 		end
-- 		node = node:parent()
-- 	end
--
-- 	-- If no function node is found, return
-- 	if not node then
-- 		print("No function found at cursor!")
-- 		return
-- 	end
--
-- 	-- Get the function node's range
-- 	local start_row, start_col, end_row, end_col = node:range()
-- end

return M
