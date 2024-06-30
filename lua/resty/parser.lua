---is a token_start for a new starting rest call
local token_START = "###"
---token_end is optional, is it necessary if the buffer contains more rows
---otherwise is the end of the buffer the end of parsing
local token_END = "---"
---is the token for comments
local token_COMMENT = "#"
---is the token for defining a variable
local token_VARIABLE = "@"

-- ---------- --
-- The Parser --
-- ---------- --
local parser = {}
parser.__index = parser

local function new_parser(init_result)
	local p = {
		state = 0,
		result = init_result,
		errors = {},
	}
	return setmetatable(p, parser)
end

function parser:is_in_init_state()
	return self.state == 0
end

function parser:set_parse_state()
	self.state = 1
end

function parser:is_in_body_state()
	return self.state == 99
end

function parser:set_body_state()
	self.state = 99
end

function parser:has_errors()
	return self.errors ~= nil and #self.errors > 0
end

function parser:add_error(line_nr, message)
	local lnr = line_nr or 1

	table.insert(self.errors, {
		col = 0,
		lnum = lnr - 1, -- NOTE is this correct?!?!
		severity = vim.diagnostic.severity.ERROR,
		message = message,
	})
end

-- parse the rest call (method + url)
function parser:parse_method_url(line, line_nr)
	local pos_space = line:find(" ")
	if not pos_space then
		self:add_error(line_nr, "expected two parts: method and url (e.g: 'GET http://foo')")
		return
	end

	local method = vim.trim(line:sub(1, pos_space - 1))
	if not method:match("^[%aZ]+$") then
		self:add_error(line_nr, "invalid method name: '" .. method .. "'. Only letters are allowed")
		return
	end
	method = method:upper()

	local url = vim.trim(line:sub(pos_space + 1, #line))

	return method, url
end

-- parse key - values pairs
-- query: key=value
-- headers: key:value)
function parser:parse_key_value(map, delimiter, line, line_nr)
	local pos = line:find(delimiter)
	if not pos then
		self:add_error(line_nr, "expected char '" .. delimiter .. "' as delimiter between key and value")
		return
	end

	local key = vim.trim(line:sub(1, pos - #delimiter))
	local value = vim.trim(line:sub(pos + #delimiter))

	if #key == 0 then
		self:add_error(line_nr, "an empty key is not allowed")
		return
	end

	if #value == 0 then
		self:add_error(line_nr, "an empty value is not allowed")
		return
	end

	if map[key] then
		self:add_error(line_nr, "the key: '" .. key .. "' already exist")
		return
	end

	map[key] = value
end

-- ---------------- --
-- The Parser Modul
-- ---------------- --
local M = {}

function M.cut_comment(line)
	local pos = string.find(line, "#")
	if not pos then
		return line
	end
	return line:sub(1, pos - 1)
end

function M.replace_variable(variables, line)
	if not variables then
		return line, nil
	end

	local _, start_pos = string.find(line, "{{")
	local end_pos, _ = string.find(line, "}}")

	if not start_pos and not end_pos then
		-- no variable found
		return line, nil
	elseif start_pos and not end_pos then
		-- error
		return nil, "missing closing brackets: '}}'"
	elseif not start_pos and end_pos then
		-- error
		return nil, "missing open brackets: '{{'"
	end

	local before = string.sub(line, 1, start_pos - 2)
	local name = string.sub(line, start_pos + 1, end_pos - 1)
	local after = string.sub(line, end_pos + 2)

	local value = variables[name]
	if not value then
		return nil, "no variable found with name: '" .. name .. "'"
	end

	local new_line = before .. value .. after
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
	else
		lines = {} -- default is an empty line
	end

	if selected > #lines then
		error("the selected row: " .. selected .. " is greater then the given rows: " .. #lines)
	end

	local p = new_parser({ readed_lines = 0, global_variables = {} })

	-- parse all lines
	for line_nr, line in ipairs(lines) do
		-- END of requests
		if vim.startswith(line, token_END) then
			break
		-- GLOBAL VARIABLE definition
		elseif p:is_in_init_state() and vim.startswith(line, token_VARIABLE) then
			local l = string.sub(line, #token_VARIABLE + 1)
			p:parse_key_value(p.result.global_variables, "=", l, line_nr)
		-- START new REQUEST
		elseif vim.startswith(line, token_START) then
			-- we can STOP here, because we are one request to far
			if selected < line_nr then
				break
			end
			p:set_parse_state()
			p.result.req_lines = {} -- reset readed lines
		--  COMMENTS or EMPTY LINE
		elseif vim.startswith(line, token_COMMENT) or #line == 0 then
			-- ignore
			goto continue
		elseif p.result.req_lines then
			table.insert(p.result.req_lines, { line_nr, line })
		end

		::continue::

		p.result.readed_lines = line_nr
	end

	return p
end

---Entry point, the parser
---@param input string | { }
---@param selected number
M.parse = function(input, selected)
	local result = M.prepare_parse(input, selected)
	if result:has_errors() then
		return result
	end

	local req_def = result.result

	if not req_def.req_lines then
		error("no request found on position: " .. selected)
	end

	local variables = req_def.global_variables or {}
	local p = new_parser({})

	for _, line_def in ipairs(req_def.req_lines) do
		local line_nr = line_def[1]
		local line = M.cut_comment(line_def[2])

		--
		-- VARIABLE definition
		if vim.startswith(line, token_VARIABLE) then
			local l = string.sub(line, #token_VARIABLE + 1)
			p:parse_key_value(variables, "=", l, line_nr)
		else
			-- replace variables
			local l, err = M.replace_variable(variables, line)
			if not err then
				line = l
			else
				p:add_error(line_nr, err)
			end

			-- METHOD and URL
			if p:is_in_init_state() then
				local method, url = p:parse_method_url(line)
				-- an error is occurred
				if not method then
					return p
				end

				p:set_parse_state()
				p.result.req = {
					method = method,
					url = url,
					headers = {},
					query = {},
				}
			--
			-- START BODY
			---@diagnostic disable-next-line: need-check-nil
			elseif line:sub(1, 2) == "{" or p:is_in_body_state() then
				p:set_body_state()
				p.result.req.body = (p.result.req.body or "") .. line
			-- END BODY
			---@diagnostic disable-next-line: need-check-nil
			elseif line:sub(1, 2) == "}" and p:is_in_body_state() then
				p:set_parse_state()
				p.result.req.body = p.result.req.body + line

			--
			-- HEADERS AND QUERIES
			else
				---@diagnostic disable-next-line: need-check-nil
				local pos_eq = line:find("=")
				---@diagnostic disable-next-line: need-check-nil
				local pos_dp = line:find(":")

				-- contains both, = and :
				if pos_eq ~= nil and pos_dp ~= nil then
					-- the first finding wins
					if pos_eq < pos_dp then
						-- set query
						p:parse_key_value(p.result.req.query, "=", line, line_nr)
					else
						-- set headers
						p:parse_key_value(p.result.req.headers, ":", line, line_nr)
					end
				elseif pos_eq ~= nil then
					-- set query
					p:parse_key_value(p.result.req.query, "=", line, line_nr)
				elseif pos_dp ~= nil then
					-- set headers
					p:parse_key_value(p.result.req.headers, ":", line, line_nr)
				end
			end
		end
	end

	return p
end

return M
