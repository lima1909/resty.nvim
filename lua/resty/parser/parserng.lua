local util = require("resty.util")
local result = require("resty.parser.result")

local INF = vim.diagnostic.severity.INFO
local ERR = vim.diagnostic.severity.ERROR

local M = {}

M.set_global_variables = function(gvars)
	result.global_variables = vim.tbl_deep_extend("force", result.global_variables, gvars)
end

M.default_opts = {
	replace_variables = true,
}

M.new = function(input, selected, opts)
	local lines = util.input_to_lines(input)

	local parser = setmetatable({
		lines = lines,
		len = #lines,
		opts = vim.tbl_deep_extend("force", M.default_opts, opts or {}),
	}, { __index = M })

	if not selected then
		selected = 1
	elseif selected > parser.len then
		selected = parser.len
	elseif selected < 0 then
		selected = 1
	end
	-- NOTE: maybe better on result?
	parser.selected = selected

	parser.r = result.new(parser.opts.replace_variables)

	return parser
end

function M:find_area()
	self.r.meta.area.starts = 1
	self.r.meta.area.ends = self.len

	-- start
	if self.selected ~= 1 then
		for i = self.selected, 1, -1 do
			if string.sub(self.lines[i], 1, 3) == "###" then
				self.r.meta.area.starts = i + 1
				break
			end
		end
	end

	-- end
	if self.selected ~= self.len then
		for i = self.selected, self.len do
			if string.sub(self.lines[i], 1, 3) == "###" and i ~= self.selected then
				self.r.meta.area.ends = i - 1
				break
			end
		end
	end

	return self.r.meta.area.starts, self.r.meta.area.ends
end

M.parse = function(input, selected, opts)
	local start = os.clock()

	local parser = M.new(input, selected, opts)
	parser:find_area()

	-- start > 1, means, there are global variables
	if parser.r.meta.area.starts > 1 then
		parser.cursor = 1
		parser.len = parser.r.meta.area.starts - 1
		parser:_parse_variables(nil, true)
	end

	parser:parse_definition(parser.r.meta.area.starts, parser.r.meta.area.ends)

	parser.r.duration = os.clock() - start
	return parser.r
end

-- parse only the fined area (e.g. between two ###)
M.parse_area = function(input, selected, opts)
	local parser = M.new(input, selected, opts)
	return parser:parse_definition(parser:find_area()).r
end

function M:parse_definition(from, to)
	self.cursor = from
	self.len = to

	local parsers = {
		M._parse_variables,
		M._parse_request,
		M._parse_headers_queries,
		M._parse_json,
		M._parse_script,
	}

	local line
	for _, parse in ipairs(parsers) do
		line = parse(self, line)
		if not line then
			break
		end
	end

	if not self.r.request.url or self.r.request.url == "" then
		self.r:add_diag(ERR, "no request URL found", 0, 0, from, to)
	end

	return self
end

local WS = "([%s]*)"
local REST = WS .. "(.*)"

-- -------
-- request
-- -------
local METHOD = "^([%a]+)"
local URL = "([^%?=&#%s]*)"
local URL_QUERY = "([^%s#]*)"
local HTTP_VERSION = "([HTTP%/%.%d]*)"

local REQUEST = METHOD .. WS .. URL .. URL_QUERY .. WS .. HTTP_VERSION .. REST

local methods =
	{ GET = "", HEAD = "", OPTIONS = "", TRACE = "", PUT = "", DELETE = "", POST = "", PATCH = "", CONNECT = "" }

function M:_parse_request(line)
	local lnum = self.cursor
	self.cursor = self.cursor + 1
	local req = self.r.request

	local ws1, ws2, ws3, rest, q, hv
	req.method, ws1, req.url, q, ws2, hv, ws3, rest = string.match(line, REQUEST)

	if not req.method then
		self.r:add_diag(ERR, "http method is missing", 0, 0, lnum)
		return line
	elseif ws1 == "" then
		self.r:add_diag(ERR, "white space after http method is missing", 0, #req.method, lnum)
		return line
	elseif req.url == "" then
		local msg = "url is missing"
		if methods[req.method] ~= "" then
			msg = "unknown http method and " .. msg
		end
		self.r:add_diag(ERR, msg, 0, #req.method + #ws1 + #req.url + #q, lnum)
		return line
	elseif #rest > 0 and not string.match(rest, "[%s]*#") then
		self.r:add_diag(
			INF,
			"invalid input after the request definition: " .. rest,
			0,
			#req.method + #ws1 + #req.url + #q + #ws2 + #hv + #ws3,
			self.cursor
		)
	end

	if hv ~= "" then
		req.http_version = hv
	end

	req.url = self.r:replace_variable(req.url, lnum)
	self.r.meta.request = lnum

	-- separate url and query, if exist
	if q ~= "" then
		if string.sub(q, 1, 1) ~= "?" then
			self.r:add_diag(ERR, "invalid query in url, must start with a '?'", 0, #req.method + #ws1 + #req.url, lnum)
			return line
		end

		q = string.sub(q, 2)
		for k, v in string.gmatch(q, "([^=&]+)=([^&]+)") do
			req.query[k] = v
		end
	end

	if methods[req.method] ~= "" then
		self.r:add_diag(INF, "unknown http method", 0, #req.method, lnum)
	end

	return line
end

-- ---------
-- variables
-- ---------
local VKEY = "^@([%a][%w%-_%.]*)"
local VVALUE = "([^%s#]*)"
local VARIABLE = VKEY .. WS .. "([=]?)" .. WS .. VVALUE .. REST

function M:_parse_variables(_, is_gloabel)
	for lnum = self.cursor, self.len do
		local line = self.lines[lnum]
		local first_char = string.sub(line, 1, 1)

		if is_gloabel and string.sub(line, 1, 3) == "###" then
			-- stop searching for global variables if you find a new request
			self.cursor = lnum
			return line
		elseif first_char == "" or first_char == "#" or line:match("^%s") then
			-- ignore comment and blank line
		elseif first_char ~= "@" then
			self.cursor = lnum
			return line
		else
			local k, ws1, d, ws2, v, ws3, rest = string.match(line, VARIABLE)
			self.cursor = lnum + 1

			if not k then
				self.r:add_diag(ERR, "valid variable key is missing", 0, 1, lnum)
			elseif d == "" then
				self.r:add_diag(ERR, "variable delimiter is missing", 0, 1 + #k + #ws1, lnum)
			elseif v == "" then
				self.r:add_diag(ERR, "variable value is missing", 0, 1 + #k + #ws1 + #d + #ws2, lnum)
			elseif #rest > 0 and not string.match(rest, "[%s]*#") then
				local col = 1 + #k + #ws1 + #d + #ws2 + #v + #ws3
				self.r:add_diag(INF, "invalid input after the variable: " .. rest, 0, col, lnum)
			end

			if k and v ~= "" then
				local key = string.sub(k, 1, 4)
				if key == "cfg." and #k > 4 then
					key = string.sub(k, 5)
					self.r.request[key] = v
				else
					self.r.variables[k] = self.r:replace_variable(v, lnum)
				end
			end
		end
	end
end

-- -------------------
-- headers and queries
-- -------------------
local HQKEY = "([^=:%s]+)"
local HQVALUE = "([^#]*)"
local HEADER_QUERY = HQKEY .. WS .. "([:=]?)" .. WS .. HQVALUE .. REST

function M:_parse_headers_queries()
	for lnum = self.cursor, self.len do
		local line = self.lines[lnum]
		local first_char = string.sub(line, 1, 1)

		if first_char == "" or first_char == "#" or line:match("^%s") then
			-- ignore comment and blank line
		elseif not string.match(first_char, "%a") then
			self.cursor = lnum
			return line
		else
			self.cursor = lnum + 1
			local k, ws1, d, ws2, v, ws3, rest = string.match(line, HEADER_QUERY)

			if d == "" then
				self.r:add_diag(ERR, "header: ':' or query: '=' delimiter is missing", 0, #k + #ws1, lnum)
			elseif v == "" then
				local kind = "header"
				if d == "=" then
					kind = "query"
				end
				self.r:add_diag(ERR, kind .. " value is missing", 0, #k + #ws1 + #d + #ws2, lnum)
			elseif #rest > 0 and not string.match(rest, "[%s]*#") then
				local col = #k + #ws1 + #d + #ws2 + #v + #ws3
				local kind = "header"
				if d == "=" then
					kind = "query"
				end
				self.r:add_diag(INF, "invalid input after the " .. kind .. ": " .. rest, 0, col, lnum)
			end

			if v ~= "" then
				if d == ":" then
					self.r.request.headers[k] = self.r:replace_variable(v, lnum)
				else
					self.r.request.query[k] = self.r:replace_variable(v, lnum)
				end
			end
		end
	end
end

function M:_parse_json()
	local json_start

	local line, first_char = self:_ignore_lines()
	if not line or first_char ~= "{" then
		return line
	else
		json_start = self.cursor
		self.cursor = self.cursor + 1

		for i = self.cursor, self.len do
			line = self.lines[i]

			-- until comment line or blank line
			if string.match(line, "^#") or string.match(line, "^%s*$") then
				self.cursor = i
				break
			end
		end

		-- remove comment or empty line
		local json_end = self.cursor - 1
		-- if only one line (without for loop) => start and end line is the same
		if json_start == self.cursor then
			json_end = self.cursor
		end

		self.r.request.body = table.concat(self.lines, "", json_start, json_end)
	end

	return line
end

function M:_parse_script()
	local line, _ = self:_ignore_lines()

	-- or > {% (tree-sitter-http) %}
	if not line or not string.match(line, "^--{%%%s*$") then
		return line
	else
		-- ignore this line
		self.cursor = self.cursor + 1
		local start = self.cursor

		for i = start, self.len do
			line = self.lines[i]
			self.cursor = i

			if string.match(line, "^--%%}%s*$") then
				-- ignore this line
				self.r.request.script = table.concat(self.lines, "\n", start, i - 1)
				return line
			end
		end

		self.r:add_diag(ERR, "missing end of script", 0, 0, self.cursor)
		return line
	end
end

function M:_ignore_lines()
	for i = self.cursor, self.len do
		local line = self.lines[i]
		local first_char = string.sub(line, 1, 1)

		if first_char == "" or first_char == "#" or line:match("^%s") then
			-- do nothing, comment or empty line
		else
			self.cursor = i
			return line, first_char
		end
	end

	self.cursor = self.len
	return nil, ""
end

return M
