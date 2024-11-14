-- https://www.jonashietala.se/blog/2024/05/26/autocomplete_with_nvim-cmp/
local parser = require("resty.parser")
local items = require("resty.extension.resty-cmp-items")

local M = {}

M.new = function()
	return setmetatable({}, { __index = M })
end

function M.get_debug_name()
	return "resty"
end

-- matches any keyword character (alphanumeric or underscore).
function M:get_keyword_pattern()
	return [=[[a-zA-Z0-9_@]*]=]
end

-- completion only for http and resty files
function M:is_available()
	return (vim.bo.filetype == "resty" or vim.bo.filetype == "http") and vim.g.resty.completion
end

function M.get_varcfg_entries(lines, row, variables)
	local entries = items.available_varcfg(variables)

	-- add not used global variables
	local parsed = parser.parse(lines, row, { replace_variables = false })
	for k, v in pairs(parsed.variables) do
		if not variables[k] then
			table.insert(entries, {
				label = k,
				labelDetails = { detail = "string", description = "" },
				insertText = "@" .. k .. " = ",
				filterText = "@" .. k .. v,
				cmp = { kind_hl_group = "String", kind_text = "Variable" },
			})
		end
	end

	return entries
end

function M.entries(lines, crrent_line, row)
	local completion_variables = string.match(crrent_line, "^@([^=]*)")
	local completion_headers = string.match(crrent_line, "^([%a]+)$")

	local entries = {}

	if crrent_line == "" or completion_variables or completion_headers then
		local parsed = parser.parse_area(lines, row, { replace_variables = false })
		local parsed_type = parsed:get_possible_types(row)

		if parsed_type.is_variable then
			entries = M.get_varcfg_entries(lines, row, parsed.variables)
		elseif parsed_type.is_headers then
			entries = items.available_headers(parsed.request.headers)
		end

		if parsed_type.is_request then
			for _, req in ipairs(items.request) do
				table.insert(entries, req)
			end
		end
	end

	return entries
end

function M:complete(r, callback)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
	callback(M.entries(lines, r.context.cursor_before_line, r.context.cursor.row))
end

-- M.get_trigger_characters = function()
-- 	-- c is the trigger for 'cfg'
-- 	return { "c" }
-- end

return M
