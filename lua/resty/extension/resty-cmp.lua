-- https://www.jonashietala.se/blog/2024/05/26/autocomplete_with_nvim-cmp/
local parser = require("resty.parser.parserng")
local items = require("resty.extension.resty-cmp-items")

local M = {}

M.new = function()
	return setmetatable({}, { __index = M })
end

-- M.get_trigger_characters = function()
-- 	-- c is the trigger for 'cfg'
-- 	return { "c" }
-- end

-- matches any keyword character (alphanumeric or underscore).
function M:get_keyword_pattern()
	return [[\k\+]]
end

M.is_valid_variable_row = function(meta, lines, row)
	local req_ends = meta.request or meta.area.ends
	-- variables are always between start and request
	if row >= meta.area.starts and row < req_ends then
		return true
	end

	-- or global variables, possible from row 1 to not variable
	for i, line in ipairs(lines) do
		local c = string.sub(line, 1, 1)
		if i > row then
			return false
		elseif c == "" or c == " " or c == "#" then
			-- ignore
		elseif i ~= row and c ~= "@" then
			return false
		elseif i == row and c == "@" then
			-- current line
			return true
		end
	end

	return false
end

M.is_valid_headers_row = function(meta, row)
	if not meta.request or meta.request >= row then
		return false
	elseif meta.body and row >= meta.body.starts then
		return false
	elseif meta.script and meta.script.starts >= row then
		return false
	end

	return true
end

function M:complete(r, callback)
	local line = r.context.cursor_before_line
	local row = r.context.cursor.row

	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
	local parsed = parser.parse_area(lines, row, { replace_variables = false })

	if string.sub(line, 1, 2) == "@c" and M.is_valid_variable_row(parsed.meta, lines, row) then
		local entries = {}
		for _, item in ipairs(items.var_cfg) do
			local key = string.sub(item.label, 6)
			if not parsed.request[key] then
				table.insert(entries, item)
			end
		end

		callback(entries)
	-- start on the first column, no spaces
	elseif line == "" or string.match(line, "^([%a]+)") and M.is_valid_headers_row(parsed.meta, row) then
		local entries = {}
		for _, header in ipairs(items.headers) do
			local found = false
			for _, v in ipairs(parsed.request.headers) do
				if header.insertText == v then
					found = true
					break
				end
			end

			if found == false then
				table.insert(entries, header)
			end
		end

		callback(entries)
	end
end

return M
