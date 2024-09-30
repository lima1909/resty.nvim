local util = require("resty.util")
local result = require("resty.parser.result")

local INF = vim.diagnostic.severity.INFO
local ERR = vim.diagnostic.severity.ERROR

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

local M = {}

M.set_global_variables = function(gvars)
	result.global_variables = vim.tbl_deep_extend("force", result.global_variables, gvars)
end

M.default_opts = {
	replace_variables = true,
}

M.parse = function(input, selected, opts)
	local start = os.clock()

	local parser = setmetatable({
		lines = util.input_to_lines(input),
		opts = vim.tbl_deep_extend("force", M.default_opts, opts or {}),
	}, { __index = M })

	parser.r = result.new(parser.opts.replace_variables)

	if not selected then
		selected = 1
	elseif selected > #parser.lines then
		selected = #parser.lines
	elseif selected < 0 then
		selected = 1
	end

	-- find the selected request
	local s, e = find_request(parser.lines, selected)

	-- start > 1, means, there are global variables
	if s > 1 then
		parser.cursor = 1
		parser.len = s - 1
		parser:_parse_variables()
	end

	parser:parse_definition(s, e)

	parser.r.duration = os.clock() - start
	return parser.r
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

	for _, parse in ipairs(parsers) do
		if not parse(self) then
			return self.parsed
		end
	end
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

function M:_parse_request()
	local line, _ = self:_ignore_lines()
	if not line then
		return nil
	end

	local req = self.r.request
	local lnum = self.cursor
	self.cursor = self.cursor + 1

	local ws1, ws2, ws3, rest, q, hv
	req.method, ws1, req.url, q, ws2, hv, ws3, rest = string.match(line, REQUEST)

	if not req.method then
		self.r:add_diag(ERR, "http method is missing", 0, 0, lnum)
		return line
	elseif ws1 == "" then
		self.r:add_diag(ERR, "white space after http method is missing", 0, #req.method, lnum)
		return line
	elseif req.url == "" then
		self.r:add_diag(ERR, "url is missing", 0, #req.method + #ws1, lnum)
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

function M:_parse_variables()
	for lnum = self.cursor, self.len do
		local line = self.lines[lnum]
		local first_char = string.sub(line, 1, 1)

		if first_char == "" or first_char == "#" or line:match("^%s") then
			-- ignore comment and blank line
		elseif first_char ~= "@" then
			self.cursor = lnum
			return line
		else
			local k, ws1, d, ws2, v, ws3, rest = string.match(line, VARIABLE)
			self.cursor = lnum + 1

			if not k then
				self.r:add_diag(ERR, "valid variable key is missing", 0, 1, lnum)
				return line
			elseif d == "" then
				self.r:add_diag(ERR, "variable delimiter is missing", 0, 1 + #k + #ws1, lnum)
				return line
			elseif v == "" then
				self.r:add_diag(ERR, "variable value is missing", 0, 1 + #k + #ws1 + #d + #ws2, lnum)
				return line
			elseif #rest > 0 and not string.match(rest, "[%s]*#") then
				local col = 1 + #k + #ws1 + #d + #ws2 + #v + #ws3
				self.r:add_diag(INF, "invalid input after the variable: " .. rest, 0, col, lnum)
			end

			local key = string.match(k, "cfg%.(.*)")
			if key and key ~= "" then
				-- configure the request
				self.r.request[key] = v
			else
				self.r.variables[k] = self.r:replace_variable(v, lnum)
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
				return
			elseif v == "" then
				local kind = "header"
				if d == "=" then
					kind = "query"
				end
				self.r:add_diag(ERR, kind .. " value is missing", 0, #k + #ws1 + #d + #ws2, lnum)
				return
			elseif #rest > 0 and not string.match(rest, "[%s]*#") then
				local col = #k + #ws1 + #d + #ws2 + #v + #ws3
				local kind = "header"
				if d == "=" then
					kind = "query"
				end
				self.r:add_diag(INF, "invalid input after the " .. kind .. ": " .. rest, 0, col, lnum)
			end

			if d == ":" then
				self.r.request.headers[k] = self.r:replace_variable(v, lnum)
			else
				self.r.request.query[k] = self.r:replace_variable(v, lnum)
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
