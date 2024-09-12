function MyInsertCompletion(findstart, base)
	print("..." .. tostring(findstart))
	if findstart == 1 then
		-- Return the start position for completion
		local line = vim.fn.getline(".")
		local start = vim.fn.col(".") - 1
		while start > 0 and line:sub(start, start):match("%w") do
			start = start - 1
		end
		return start
	else
		-- Return a list of matches
		local suggestions = { "apple", "banana", "cherry", "date", "elderberry" }
		return vim.tbl_filter(function(val)
			return vim.startswith(val, base)
		end, suggestions)
	end
end

-- Set the omnifunc to your custom completion function
vim.bo.omnifunc = "v:lua.MyInsertCompletion"
-- To use the custom completion in insert mode, type: Ctrl-X Ctrl-O
--
--
--
--[[

| input           | starts with                                                    |
|-----------------|----------------------------------------------------------------|
| delimiter       | ### (optional)                                                 |
| comments        | # (optional)                                                   |


* variable        
  - start: with @ (optional)
  - end: not @
* method_url      
  - start: after variable or first, starts with a letter, and 2 or 3 parts 
  - end: only one line
* header or query 
  - start: after method_url, starts with a letter, contains : or = 
  - end: } (json_body), --%} (script_body), END
* json body        
  - start: {
  - end: }        
* script body     
  - start: --{% 
  - end: --%} 


* ignore lines
  - comments (delimiters)
  - blank lines

1) while is_variable  
2) method_url (one line)
3) json_body | script_body | header_query 
	-> header_query -> while header_query -> json_body | script_body | END
	-> json_body    -> while json_body    -> script_body | END
	-> script_body  -> while script_body  -> END


]]

-- local v = require("resty.parser.variables")

local M = { global_variables = {} }

M.set_global_variables = function(gvars)
	M.global_variables = vim.tbl_deep_extend("force", M.global_variables, gvars)
end

function M.new(input)
	return setmetatable({
		iter = require("resty.parser.iter").new(input),
		parsed = {},
	}, { __index = M })
end

function M.parse_request(input)
	local p = M.new(input)

	p.parsed = {
		request = {
			query = {},
			headers = {},
		},
		variables = {},
	}

	local parsers = {
		M._parse_variable,
		M._parse_method_url,
		M._parse_headers_query,
		M._parse_json_body,
		M._parse_script_body,
	}

	for _, parse in ipairs(parsers) do
		if not parse(p) then
			return p.parsed
		end
	end

	if p.iter.cursor < #p.iter.lines then
		-- handle this, maybe with: vim.api.nvim_buf_set_extmark
		print(
			"Hint: Process only: "
				.. p.iter.cursor
				.. " from possible: "
				.. #p.iter.lines
				.. " lines. The remaining lines are ignored."
		)
	end

	return p.parsed
end

-- ----------------------------------------------------------------------------
--

local VARIABLE = "^@([^%s^=]+)[%s]*=[%s]*([^#^%s]+)"

M._pv = function(line)
	local k, v = string.match(line, VARIABLE)
	if not k then
		error("invalid variable name in line: " .. line, 0)
	end
	if not v then
		error("invalid variable value in line: " .. line, 0)
	end

	return k, v
end

local function _create_variable_parser(self)
	return self:parse_matching_line_ng("@", M._pv, function(k, v)
		self.parsed.variables[k] = v
	end)
end

local REQUEST = "^([%w]+)[%s]+([%w%_-:/%?&]+)[%s]*([%w%/%.%d]*)"

function M:_parse_method_url_ng()
	local line = self.iter.lines[self.iter.cursor]
	if not line then
		error("no method and url found", 0)
	end
	self.iter.cursor = self.iter.cursor + 1

	local m, u, h = string.match(line, REQUEST)
	if not m then
		error("invalid method in line: " .. line, 0)
	end
	if not u then
		error("invalid url in line: " .. line, 0)
	end
	-- valdiate h HTTP/1 ,0.9, 2

	self.parsed.request.method = m
	self.parsed.request.url = u
	self.parsed.request.http_version = h or ""

	return line
end

local HEADER = "^([%w][^%s^:^%#]*)[%s]*:[%s]*([^#]+)[#%.]*"
local QUERY = "^([%w][^%s^=^%#]*)[%s]*=[%s]*([^#]+)[#%.]*"

M._phq = function(line)
	local what = 2 -- query

	local k, v = string.match(line, HEADER)
	if not k then
		k, v = string.match(line, QUERY)
		if not k then
			error("invalid header or query key in line: " .. line, 0)
		end
	else
		what = 1 --header
	end

	if not v then
		error("invalid value in line: " .. line, 0)
	else
		return k, v, what
	end
end

local function _create_header_query_parser(self)
	return self:parse_matching_line_ng("%w", M._phq, function(k, v, what)
		if what == 1 then
			self.parsed.request.headers[k] = v
		elseif what == 2 then
			self.parsed.request.query[k] = v
		end
	end)
end

function M:_parse_json_ng()
	return self:parse_body_ng("({)[%s]*", "(})[%s]*", function(body, is_complete)
		if is_complete == false then
			error("not closing json body: " .. body, 0)
		else
			self.parsed.request.body = body
		end
	end)
end

function M:parse_body_ng(begin, stop, collect_result)
	for i = self.iter.cursor, self.iter.len do
		local line = self.iter.lines[i]
		local first_char = string.sub(line, 1, 1)

		if not first_char or first_char == "" or first_char == "#" or line:match("^%s") then
			self.iter.cursor = i
		else
			break
		end
	end

	local body = nil

	for i = self.iter.cursor, self.iter.len do
		local line = self.iter.lines[i]
		local first_char = string.sub(line, 1, 1)

		if not body and string.match(first_char, begin) then
			body = line
		elseif string.match(first_char, stop) then
			self.iter.cursor = i
			collect_result(body .. line, true)
			return line
		elseif body then
			body = body .. line
		end
	end

	collect_result(body, false)
	return nil
end

function M.parse_request_ng(input)
	local p = M.new(input)

	p.parsed = {
		request = {
			query = {},
			headers = {},
		},
		variables = {},
	}

	local parsers = {
		_create_variable_parser,
		M._parse_method_url_ng,
		_create_header_query_parser,
		M._parse_json_ng,
		-- M._parse_script_body,
	}

	for _, parse in ipairs(parsers) do
		if not parse(p) then
			return p.parsed
		end
	end

	return p.parsed
end

function M:parse_matching_line_ng(match, parser, collect_result)
	for i = self.iter.cursor, self.iter.len do
		local line = self.iter.lines[i]
		local first_char = string.sub(line, 1, 1)

		if not first_char or first_char == "" or first_char == "#" or line:match("^%s") then
			-- do nothing, comment or empty line
		elseif string.match(first_char, match) then
			collect_result(parser(line))
		else
			-- TODO: this will be go better
			self.iter.cursor = i
			return line
		end
	end

	return nil
end

--
-- ----------------------------------------------------------------------------

M._is_variable = function(line)
	return string.sub(line, 1, 1) == "@"
end

function M:_parse_variable()
	while true do
		local line, is_variable = self.iter:next(M._is_variable)
		if not line or is_variable == false then
			return line
		end

		local k = string.match(line, "^@([%w%-_]+[%s]*)=")
		if not k then
			error("an empty variable name is not allowed: '" .. line .. "'", 0)
		end

		local v = string.sub(line, #k + 3) -- add '@' and '=' for the correct length
		if not v then
			error("an empty variable value is not allowed: '" .. line .. "'", 0)
		end

		k = vim.trim(k)
		v = vim.trim(v)

		-- CHECK duplicate
		-- if self.parsed.variables[k] then
		-- error("the variable key: '" .. key .. "' already exist")
		-- end

		self.parsed.variables[k] = v
		-- TODO: a good idea ?!?!
		-- self.iter.variables = self.parsed.variables
	end
end

M._starts_with_letter = function(line)
	local first_char = string.sub(line, 1, 1)
	return (first_char >= "a" and first_char <= "z") or (first_char >= "A" and first_char <= "Z")
end

function M:_parse_method_url()
	local line, is_mu = self.iter:next(M._starts_with_letter)
	if not line or is_mu == false then
		return line
	end

	local parts = line:gmatch("([^ ]+)")

	local method = vim.trim(parts())
	if not method:match("^[%aZ]+$") then
		error("invalid method name: '" .. method .. "'. Only letters are allowed", 0)
	end

	local url = vim.trim(parts())
	if string.sub(url, 1, 4) == "http" == false then
		error("invalid url: '" .. url .. "'. Must staret with 'http'", 0)
	end

	self.parsed.request.method = method:upper()
	self.parsed.request.url = url

	return line
end

function M:_parse_headers_query()
	while true do
		local line, is_hq = self.iter:next(function(l)
			local headers = string.match(l, "^([%w%-]+):")
			if headers then
				local v = string.sub(l, #headers + 2)
				v = vim.trim(v)
				if #v == 0 then
					error("an empty  header value is not allowed", 0)
				end
				self.parsed.request.headers[headers] = v
				return true
			else
				local query = string.match(l, "^([%w%-_%.]+[%s]*)=")
				if query then
					local v = string.sub(l, #query + 2)
					v = vim.trim(v)
					if #v == 0 then
						error("an empty query value is not allowed", 0)
					end
					self.parsed.request.query[vim.trim(query)] = v
					return true
				end
			end

			return false
		end)
		if not line or is_hq == false then
			return line
		end
	end
end

-- parse definition:
--	return not processed line and current selected json
--	line == nil -> no more lines left
--	json == nil -> no json found
function M:_parse_body(start, end_line)
	local line, is_body = self.iter:next(start)
	if not line or is_body == false then
		return line
	end

	local body_str = ""
	while true do
		body_str = body_str .. line

		line = self.iter.lines[self.iter.cursor]
		if not line then
			-- error("parsing body hast started, but not ended: " .. body_str, 0)
			return line, body_str
		elseif string.sub(line, 1, #end_line) == end_line then
			return line, body_str .. line
		else
			-- TODO: a good idea ?!?!
			-- line = v.replace_variable(self.variables, line, {}, {}) -- replacements, global_variables
			self.iter.cursor = self.iter.cursor + 1
		end
	end
end

local start_json = function(line)
	return string.sub(line, 1, 1) == "{" and #line == 1
end

function M:_parse_json_body()
	local line, str = self:_parse_body(start_json, "}")
	self.parsed.request.body = str
	return line
end

local start_script = function(line)
	return string.sub(line, 1, 4) == "--{%" and #line == 4
end

function M:_parse_script_body()
	local line, str = self:_parse_body(start_script, "--%}")
	self.parsed.request.script = str
	return line
end

return M
