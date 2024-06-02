---is a token_start for a new starting rest call
local token_START = "###"
---token_end is optional, is it necessary if the buffer contains more rows
---otherwise is the end of the buffer the end of parsing
local token_END = "---"
---is the token for comments
local token_COMMENT = "#"

---is the token for defining a variable
local token_VARIABLE = "@"

---State-transitions: |init| -> |parse|
local state_INIT = 0
local state_PARSE = 1

local function new_parser()
	return { state = state_INIT }
end

local function split_into_key_value(line, pos, nr)
	local key = vim.trim(line:sub(1, pos - 1))
	local value = vim.trim(line:sub(pos + 1))

	if #key == 0 then
		error("an empty key is not allowed [" .. nr .. "]")
	end

	if #value == 0 then
		error("an empty value is not allowed [" .. nr .. "]")
	end

	return key, value
end

local function parse_variable(line, nr)
	line = string.sub(line, #token_VARIABLE + 1)
	local pos = line:find("=")
	if not pos then
		error("expected char '=' as delimiter between key and value [" .. nr .. "]")
	end

	return split_into_key_value(line, pos, nr)
end

---Parse the rest call (method + url)
---@param line string
local function parse_method_url(line, nr)
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

function M.replace_variable(variables, line)
	if not variables then
		return line
	end

	local _, start_pos = string.find(line, "{{")
	if not start_pos then
		return line
	end

	local end_pos, _ = string.find(line, "}}")
	if not end_pos then
		return line
	end

	local before = string.sub(line, 1, start_pos - 2)
	local name = string.sub(line, start_pos + 1, end_pos - 1)
	local after = string.sub(line, end_pos + 2)

	name = variables[name]
	if not name then
		return line
	end

	local new_line = before .. name .. after
	return M.replace_variable(variables, new_line)
end

---This is preparing the parser step. Go over the file and find the correct request definition.
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
	local result = { readed_lines = 0, global_variables = {} }

	-- parse all lines
	for nr, line in ipairs(lines) do
		-- END of requests
		if vim.startswith(line, token_END) then
			break

		-- GLOBAL VARIABLE definition
		elseif p.state == state_INIT and vim.startswith(line, token_VARIABLE) then
			local name, value = parse_variable(line, nr)
			result.global_variables[name] = value

		-- START new REQUEST
		elseif vim.startswith(line, token_START) then
			-- we can STOP here, because we are one request to far
			if selected < nr then
				break
			end

			p.state = state_PARSE
			result.req_lines = {} -- reset readed lines

		--  COMMENTS or EMPTY LINE
		elseif vim.startswith(line, token_COMMENT) or #line == 0 then
			-- ignore
			goto continue
		elseif result.req_lines then
			table.insert(result.req_lines, line)
		end

		::continue::

		result.readed_lines = nr
	end

	return result
end

---Entry point, the parser
---@param input string | { }
---@param selected number
M.parse = function(input, selected)
	local req_def = M.prepare_parse(input, selected)
	if not req_def.req_lines then
		error("no request found on position: " .. selected)
	end

	local result = {}
	local variables = req_def.global_variables or {}
	local p = new_parser()

	for idx, line in ipairs(req_def.req_lines) do
		--
		-- VARIABLE definition
		if vim.startswith(line, token_VARIABLE) then
			local name, value = parse_variable(line, idx)
			variables[name] = value
		else
			-- replace variables
			line = M.replace_variable(variables, line)

			-- METHOD and URL
			if p.state == state_INIT then
				p.state = state_PARSE

				local method, url = parse_method_url(line)
				result.req = {
					method = method,
					url = url,
					headers = {},
					query = {},
				}
			else
				-- HEADERS AND QUERIES
				local pos_eq = line:find("=")
				local pos_dp = line:find(":")

				-- contains both, = and :
				if pos_eq ~= nil and pos_dp ~= nil then
					-- the first finding wins
					if pos_eq < pos_dp then
						-- set query
						local key, value = split_into_key_value(line, pos_eq, idx)
						result.req.query[key] = value
					else
						-- set headers
						local key, value = split_into_key_value(line, pos_dp, idx)
						result.req.headers[key] = value
					end
				elseif pos_eq ~= nil then
					-- set query
					local key, value = split_into_key_value(line, pos_eq, idx)
					result.req.query[key] = value
				elseif pos_dp ~= nil then
					-- set headers
					local key, value = split_into_key_value(line, pos_dp, idx)
					result.req.headers[key] = value
				end
			end
		end
	end

	return result
end

return M
