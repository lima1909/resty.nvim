local exec = require("resty.exec")
local util = require("resty.util")

local function info(msg, col, end_col)
	return { col = col, end_col = end_col, message = msg, severity = vim.diagnostic.severity.INFO }
end

local function err(msg, col, end_col)
	return { col = col, end_col = end_col, message = msg, severity = vim.diagnostic.severity.ERROR }
end

local function find_request(lines, selected)
	local len = #lines

	local start_req = 1
	local end_req = len

	-- start
	if selected ~= 1 then
		for i = selected, 1, -1 do
			if string.sub(lines[i], 1, 3) == "###" then
				start_req = i + 1
				break
			end
		end
	end

	-- end
	if selected ~= len then
		for i = selected, len do
			if string.sub(lines[i], 1, 3) == "###" and i ~= selected then
				end_req = i - 1
				break
			end
		end
	end

	return start_req, end_req
end

local M = { global_variables = {} }

M.set_global_variables = function(gvars)
	M.global_variables = vim.tbl_deep_extend("force", M.global_variables, gvars)
end

function M.parse(input, selected)
	local start = os.clock()

	local p = setmetatable({
		lines = util.input_to_lines(input),
		parsed = {
			request = {},
			variables = {},
			replacements = {},
			diagnostics = {},
		},
	}, { __index = M })

	if not selected then
		selected = 1
	elseif selected > #p.lines then
		selected = #p.lines
	elseif selected < 0 then
		selected = 1
	end

	-- find the selected request
	local s, e = find_request(p.lines, selected)

	-- start > 1, means, there are global variables
	if s > 1 then
		p.cursor = 1
		p.len = s - 1
		p:_parse_variables()
	end

	p:parse_request(s, e)
	p:replace_variables()

	p.parsed.duration = os.clock() - start

	return p
end

function M:parse_request(from, to)
	self.cursor = from
	self.len = to

	local parsers = {
		M._parse_variables,
		M._parse_request_definition,
		M._parse_headers_queries,
		M._parse_json,
		M._parse_script,
	}

	local line
	for _, parse in ipairs(parsers) do
		line = parse(self, line)
		if not line then
			return self.parsed
		end
	end
end

function M:add_diagnostic(diag)
	if diag then
		diag.lnum = self.cursor - 1 -- NOTE: lnum is 0 indexed, end readed_lines starts by 1
		table.insert(self.parsed.diagnostics, diag)
	end

	return self
end

function M:has_diagnostics()
	return #self.parsed.diagnostics > 0
end

local WS = "([%s]*)"
local REST = WS .. "(.*)"

-- request definition
local METHOD = "^([%a]+)"
local URL = "([^%?=&#%s]*)"
local URL_QUERY = "([^%s#]*)"
local HTTP_VERSION = "([HTTP%/%.%d]*)"

local REQUEST = METHOD .. WS .. URL .. URL_QUERY .. WS .. HTTP_VERSION .. REST

local methods =
	{ GET = "", HEAD = "", OPTIONS = "", TRACE = "", PUT = "", DELETE = "", POST = "", PATCH = "", CONNECT = "" }

function M.parse_request_definition(line)
	local m, ws1, url, q, ws2, hv, ws3, rest = string.match(line, REQUEST)

	if not m then
		return nil, err("http method is missing ", 0, 1)
	elseif ws1 == "" then
		return nil, err("white space after http method is missing", 0, #m)
	elseif url == "" then
		return nil, err("url is missing", 0, #m + #ws1)
	elseif #rest > 0 and not string.match(rest, "[%s]*#") then
		return nil,
			info("invalid input after the request definition: " .. rest, 0, #m + #ws1 + #url + #q + #ws2 + #hv + #ws3)
	end

	local r = { method = m, url = url }
	if hv ~= "" then
		r.http_version = hv
	end

	-- separate url and query, if exist
	if q ~= "" then
		if string.sub(q, 1, 1) ~= "?" then
			return r, err("invalid query in url, must start with a '?'", 0, #m + #ws1 + #url)
		end

		r.query = {}
		q = string.sub(q, 2)
		for k, v in string.gmatch(q, "([^=&]+)=([^&]+)") do
			r.query[k] = v
		end
	end

	if methods[m] ~= "" then
		return r, info("unknown http method: " .. m, 0, #m)
	else
		return r, nil
	end
end

function M:_parse_request_definition(line)
	local req, d = M.parse_request_definition(line)
	if req then
		self.parsed.request.method = req.method
		self.parsed.request.url = req.url
		self.parsed.request.http_version = req.http_version
		if req.query then
			self.parsed.request.query = req.query
		end
	end
	self:add_diagnostic(d)
	self.cursor = self.cursor + 1
	return line
end

function M.parse_key_value(line, match, kind, space)
	-- space for @ by variable is 1 otherwise 0
	space = space or 0

	local key, ws1, delimiter, ws2, value, ws3, rest = string.match(line, match)

	if not key then
		return nil, nil, nil, err("valid " .. kind .. " key is missing", 0, space)
	elseif delimiter == "" then
		return key, nil, nil, err(kind .. " delimiter is missing", 0, space + #key + #ws1)
	elseif value == "" then
		return key, nil, delimiter, err(kind .. " value is missing", 0, space + #key + #ws1 + #delimiter + #ws2)
	elseif #rest > 0 and not string.match(rest, "[%s]*#") then
		local col = space + #key + #ws1 + #delimiter + #ws2 + #value + #ws3
		return key, value, delimiter, info("invalid input after the request definition: " .. rest, 0, col)
	end

	return key, value, delimiter, nil
end

local VKEY = "^@([%a][%w%-_%.]*)"
local VVALUE = "([%w%-_%%{}:$>]*)"
local VARIABLE = VKEY .. WS .. "([=]?)" .. WS .. VVALUE .. REST
local CFG = "cfg."

function M.parse_variable(line)
	return M.parse_key_value(line, VARIABLE, "variable", 1)
end

function M:_parse_variables(_)
	return self:parse_matching_line("@", M.parse_variable, function(k, v, _, e)
		if k then
			if vim.startswith(k, CFG) then
				local c = string.sub(k, 5)
				if c == "" then
					self:add_diagnostic(err("empty cfg variable is not allowed", 0, #k))
				else
					self.parsed.request[c] = v
				end
			else
				self.parsed.variables[k] = v
			end
		end

		self:add_diagnostic(e)
	end)
end

local HKEY = "^([%a][!#$%%&'*+%^_`|~%w%-%.]+)"
local HVALUE = "([^#]*)"
local HEADER = HKEY .. WS .. "([:]?)" .. WS .. HVALUE .. REST

function M.parse_header(line)
	return M.parse_key_value(line, HEADER, "header")
end

local QKEY = "^([%a][%w%-_%%]*)"
local QVALUE = "([%w%-_%%{}]*)"
local QUERY = QKEY .. WS .. "([=]?)" .. WS .. QVALUE .. REST

function M.parse_query(line)
	return M.parse_key_value(line, QUERY, "query")
end

function M._parse_header_query(line)
	local k, v, d, e = M.parse_key_value(line, HEADER, "header")
	if d == ":" then
		return k, v, d, e
	end

	return M.parse_key_value(line, QUERY, "query")
end

function M:_parse_headers_queries()
	self.parsed.request.headers = {}
	self.parsed.request.query = self.parsed.request.query or {}

	return self:parse_matching_line("%w", M._parse_header_query, function(k, v, d, e)
		if not e then
			if d == ":" then
				self.parsed.request.headers[k] = v
			else
				self.parsed.request.query[k] = v
			end
		end

		self:add_diagnostic(e)
	end)
end

function M:_parse_json(line)
	line, self.parsed.request.body = self:_parse_body(line, "^{")
	return line
end

function M:_parse_script(line)
	for i = self.cursor, self.len do
		self.cursor = i

		line = self.lines[i]
		local first_char = string.sub(line, 1, 1)

		if first_char == "" or first_char == "#" or line:match("^%s") then
			-- do nothing, comment or empty line
		else
			break
		end
	end

	local l, body = self:_parse_body(line, "^--{%%")
	if body then
		self.parsed.request.script = body
	else
		-- or > {% (tree-sitter-http) %}
		l, body = self:_parse_body(line, "^>%s{%%")
		if body then
			self.parsed.request.script = body
		end
	end
	return l
end

function M:_parse_body(line, body_start)
	local start = self.cursor

	if not string.match(line, body_start) then
		return line, nil
	end

	for i = self.cursor, self.len do
		line = self.lines[i]
		self.cursor = i

		-- until blank line
		if string.match(line, "^%s*$") then
			return line, table.concat(self.lines, "", start, i)
		-- until comment line
		elseif string.match(line, "^#") then
			return line, table.concat(self.lines, "", start, i - 1)
		end
	end

	self.cursor = self.len
	return nil, table.concat(self.lines, "", start, self.len)
end

function M:parse_matching_line(match, parser, collect_result)
	for i = self.cursor, self.len do
		local line = self.lines[i]
		local first_char = string.sub(line, 1, 1)
		self.cursor = i

		if first_char == "" or first_char == "#" or line:match("^%s") then
			-- do nothing, comment or empty line
		elseif string.match(first_char, match) then
			collect_result(parser(line))
		else
			return line
		end
	end

	self.cursor = self.len
	return nil
end

M._replace_variable = function(line, variables, replacements)
	replacements = replacements or {}

	line = string.gsub(line, "{{(.-)}}", function(key)
		local value
		local symbol = key:sub(1, 1)

		-- environment variable
		if symbol == "$" then
			value = os.getenv(key:sub(2):upper())
			table.insert(replacements, { from = key, to = value, type = "env" })
		-- commmand
		elseif symbol == ">" then
			value = exec.cmd(key:sub(2))
			table.insert(replacements, { from = key, to = value, type = "cmd" })
		-- prompt
		elseif symbol == ":" then
			value = vim.fn.input("Input for key " .. key:sub(2) .. ": ")
			table.insert(replacements, { from = key, to = value, type = "prompt" })
		-- variable
		else
			value = variables[key]
			if value then
				table.insert(replacements, { from = key, to = value, type = "var" })
			else
				value = M.global_variables[key]
				if not value then
					error("invalid variable key: " .. key, 0)
				end
				table.insert(replacements, { from = key, to = value, type = "global_var" })
			end
		end

		return value
	end)

	return line, replacements
end

function M:replace_variables()
	if not self.parsed.variables and #self.parsed.variables == 0 then
		return
	end

	-- replace variables in variables-values
	for k, v in pairs(self.parsed.variables) do
		self.parsed.variables[k] = M._replace_variable(v, self.parsed.variables, self.parsed.replacements)
	end

	-- replace variables in url
	self.parsed.request.url =
		M._replace_variable(self.parsed.request.url, self.parsed.variables, self.parsed.replacements)

	-- replace variables in query-values
	for k, v in pairs(self.parsed.request.query) do
		self.parsed.request.query[k] = M._replace_variable(v, self.parsed.variables, self.parsed.replacements)
	end

	-- replace variables in headers-values
	for k, v in pairs(self.parsed.request.headers) do
		self.parsed.request.headers[k] = M._replace_variable(v, self.parsed.variables, self.parsed.replacements)
	end
end

return M

-- function MyInsertCompletion(findstart, base)
-- 	print("..." .. tostring(findstart))
-- 	if findstart == 1 then
-- 		-- Return the start position for completion
-- 		local line = vim.fn.getline(".")
-- 		local start = vim.fn.col(".") - 1
-- 		while start > 0 and line:sub(start, start):match("%w") do
-- 			start = start - 1
-- 		end
-- 		return start
-- 	else
-- 		-- Return a list of matches
-- 		local suggestions = { "apple", "banana", "cherry", "date", "elderberry" }
-- 		return vim.tbl_filter(function(val)
-- 			return vim.startswith(val, base)
-- 		end, suggestions)
-- 	end
-- end
--
-- -- Set the omnifunc to your custom completion function
-- vim.bo.omnifunc = "v:lua.MyInsertCompletion"
-- -- To use the custom completion in insert mode, type: Ctrl-X Ctrl-O
