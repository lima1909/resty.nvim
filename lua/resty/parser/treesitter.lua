local format = require("resty.output.format")

local M = {}

M.parse = function(bufnr)
	bufnr = bufnr or 0

	local start = vim.loop.hrtime()

	local parser = vim.treesitter.get_parser(bufnr, "http")
	local tree = parser:parse()[1] -- Parse the current buffer and get the syntax tree
	local root = tree:root()

	for children in root:iter_children() do
		print(tostring(children:type()))
		-- if children:type() == "comment" then
		-- local val_com = vim.treesitter.get_node_text(children, buf) -- Get the text for the node
		-- if vim.startswith(val_com, "###") then
		-- print("--" .. tostring(children:range()))
		-- print(tostring(row) .. ": " .. tostring(children:type()) .. " | " .. tostring(children:range()))
		-- if children:range() >= row then
		-- 	print("JA")
		-- 	for cc in children:iter_children() do
		-- 		local val = vim.treesitter.get_node_text(cc, buf) -- Get the text for the node
		-- 		print("    " .. tostring(cc:type()) .. ": " .. val)
		-- 	end
		-- end
		-- break
		-- end
		-- end
	end

	local time = format.duration_to_str(vim.loop.hrtime() - start)
	print("Time: " .. time)
end

M.query = function(bufnr)
	bufnr = bufnr or 0

	local start = vim.loop.hrtime()

	local parser = vim.treesitter.get_parser(bufnr, "http")
	local tree = parser:parse()[1] -- Parse the current buffer and get the syntax tree

	local query = vim.treesitter.query.parse("http", "(comment) @comment")

	print("start ...")
	-- Execute the query on the syntax tree
	for id, node, metadata in query:iter_captures(tree:root(), bufnr) do
		local capture_name = query.captures[id] -- The name of the capture group in the query
		print("- " .. capture_name)
		local start_row, start_col, end_row, end_col = node:range()

		if capture_name == "comment" then
			local name = vim.treesitter.get_node_text(node, bufnr) -- Get the text for the node
			-- if vim.startswith(name, "###") then
			print("Found comment:", name, "at", start_row, start_col)
			-- end
		end
	end

	local time = format.duration_to_str(vim.loop.hrtime() - start)
	print("Time: " .. time)
end

return M
