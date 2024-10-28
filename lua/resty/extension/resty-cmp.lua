-- https://www.jonashietala.se/blog/2024/05/26/autocomplete_with_nvim-cmp/
local parser = require("resty.parser")
local items = require("resty.extension.resty-cmp-items")

local M = {}

M.new = function()
	return setmetatable({}, { __index = M })
end

-- matches any keyword character (alphanumeric or underscore).
function M:get_keyword_pattern()
	return [[\k\+]]
end

function M:complete(r, callback)
	if not vim.g.resty.completion then
		return
	end

	local line = r.context.cursor_before_line
	local row = r.context.cursor.row

	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
	local parsed = parser.parse_area(lines, row, { replace_variables = false })

	-- completion for variables
	if (line == "" or string.match(line, "^@([^=]*)")) and parsed:is_valid_variable_row(row) then
		-- add not used configs
		local entries = {}
		for _, item in ipairs(items.varcfg) do
			if not parsed.request[item.label] then
				table.insert(entries, item)
			end
		end

		-- add not used global variables
		local parsed_req = parser.parse(lines, row, { replace_variables = false })
		for k, v in pairs(parsed_req.variables) do
			if not parsed.variables[k] then
				table.insert(entries, {
					label = k,
					labelDetails = { detail = "string", description = "" },
					insertText = k .. " = ",
					filterText = k .. v,
					cmp = { kind_hl_group = "String", kind_text = "variable" },
				})
			end
		end

		callback(entries)
	-- completion for headers
	-- start on the first column, no spaces
	elseif (line == "" or string.match(line, "^([%a]+)$")) and parsed:is_valid_headers_row(row) then
		local entries = items.available_headers(parsed.request.headers)
		callback(entries)
	end
end

-- completion only for http and resty files
function M:is_available()
	return vim.bo.filetype == "resty" or vim.bo.filetype == "http"
end

-- M.get_trigger_characters = function()
-- 	-- c is the trigger for 'cfg'
-- 	return { "c" }
-- end

return M
