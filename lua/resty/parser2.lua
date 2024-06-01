---is a token_start for a new starting rest call
local token_START = "###"
---token_end is optional, is it necessary if the buffer contains more rows
---otherwise is the end of the buffer the end of parsing
local token_END = "---"
---is the token for comments
local token_COMMENT = "#"

---is the token for defining a variable
local token_VARIABLE = "@"

---State-transitions: |init| -> |new| -> |call|
local state_INIT = 0
local state_PARSE_REQ = 1

local parser = {}
parser.__index = parser

local function new_parser()
	local p = { state = state_INIT }
	return setmetatable(p, parser)
end

local function split_into_key_value(line, pos_eq, nr)
	local key = vim.trim(line:sub(1, pos_eq - 1))
	local value = vim.trim(line:sub(pos_eq + 1))

	if #key == 0 then
		error("an empty key is not allowed [" .. nr .. "]")
	end

	if #value == 0 then
		error("an empty value is not allowed [" .. nr .. "]")
	end

	return key, value
end

---Parse the given variable
---Example: @hostname = api.example.com
---@param line string
function parser:parse_variable(line, nr)
	local l = string.sub(line, #token_VARIABLE + 1)
	local pos_eq = l:find("=")
	if not pos_eq then
		error("expected char = as delimiter between key and value [" .. nr .. "]")
	end

	return split_into_key_value(l, pos_eq, nr)
end

---Parse the rest call (method + url)
---@param line string
function parser:parse_method_url(line, nr)
	local pos_space = line:find(" ")
	if not pos_space then
		return error("expected two parts: method and url (e.g: 'GET http://foo'), got: " .. line .. " [" .. nr .. "]")
	end

	local method = vim.trim(line:sub(1, pos_space - 1)):upper()
	local url = vim.trim(line:sub(pos_space + 1, #line))
	return method, url
end

-- the parser modul
local M = {}

---Entry point, the parser
---@param input string | { }
---@param selected number
M.prepare_parse = function(input, selected)
	local lines
	if type(input) == "string" then
		lines = vim.split(input, "\n")
	elseif type(input) == "table" then
		lines = input
	end

	if selected > #lines then
		error("the selected row: " .. selected .. " is greater then the given rows: " .. #lines)
	end

	local p = new_parser()
	local result = { readed_lines = 0 }

	-- parse all lines
	for nr, line in ipairs(lines) do
		-- END of requests
		if vim.startswith(line, token_END) then
			break
		-- GLOBAL VARIABLE definition
		elseif p.state == state_INIT and vim.startswith(line, token_VARIABLE) then
			if not result.global_variables then
				result.global_variables = {}
			end

			local name, value = p:parse_variable(line, nr)
			result.global_variables[name] = value
		-- START new REQUEST
		elseif vim.startswith(line, token_START) then
			-- we can STOP here
			if selected < nr then
				break
			end

			p.state = state_PARSE_REQ
			-- reset readd lines
			result.req_lines = {}
		--  COMMENTS or EMPTY LINE
		elseif vim.startswith(line, token_COMMENT) or #line == 0 then
			goto continue
		elseif result.req_lines then
			result.req_lines[nr] = line
		end

		::continue::

		result.readed_lines = nr
	end

	return result
end

return M
