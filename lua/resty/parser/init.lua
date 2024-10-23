local util = require("resty.util")
local result = require("resty.parser.result")

local INF = vim.diagnostic.severity.INFO
local WRN = vim.diagnostic.severity.WARN
local ERR = vim.diagnostic.severity.ERROR

local M = {}

M.set_global_variables = function(gvars)
	result.global_variables = vim.tbl_deep_extend("force", result.global_variables, gvars)
end

M.new = function(input, selected, opts)
	local lines = util.input_to_lines(input)

	local parser = setmetatable({
		lines = lines,
		len = #lines,
	}, { __index = M })

	if not selected then
		selected = 1
	elseif selected > parser.len then
		selected = parser.len
	elseif selected <= 0 then
		selected = 1
	end
	-- NOTE: maybe better on result?
	parser.selected = selected

	parser.r = result.new(opts)

	return parser
end

function M:find_area()
	self.r.meta.area.starts = 1
	self.r.meta.area.ends = self.len

	-- start
	for i = self.selected, 1, -1 do
		if string.sub(self.lines[i], 1, 3) == "###" then
			self.r.meta.area.starts = i + 1
			break
		end
	end

	-- end
	for i = self.selected, self.len do
		if string.sub(self.lines[i], 1, 3) == "###" and i ~= self.selected then
			self.r.meta.area.ends = i - 1
			break
		end
	end

	return self.r.meta.area.starts, self.r.meta.area.ends
end

M.parse = function(input, selected, opts)
	local start = os.clock()

	local parser = M.new(input, selected, opts)
	local s, e = parser:find_area()

	-- start > 1, means, there are global variables
	if s > 1 then
		parser.cursor = 1
		parser.len = s - 1
		parser:_parse_variables(nil, true)
	end

	parser:parse_definition(s, e)

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
		M._parse_request,
		M._parse_headers_queries,
		M._parse_json,
		M._parse_script,
		M._parse_after_last,
	}

	local line = self:_parse_variables()
	-- no more lines available
	-- only variables are ok for global area
	if not line then
		-- LOCAL variables
		if self.r.meta.area.starts ~= 1 then
			self.r:add_diag(ERR, "no request URL found", 0, 0, from, to)
		-- GLOBAL variables: self.r.meta.area.starts = 1
		elseif self.r.opts.is_in_execute_mode == true then
			self.r:add_diag(ERR, "no request URL found. please set the cursor to an valid request", 0, 0, from, to)
		end
		return self
	end

	for _, parse in ipairs(parsers) do
		line = parse(self, line)
		if not line then
			break
		end
	end

	if not self.r.request.url or self.r.request.url == "" then
		self.r:add_diag(ERR, "no request URL found", 0, 0, from, to)
	end

	self.r:url_with_query_string()
	return self
end

local WS = "([%s]*)"
local REST = "(.*)"
local VALUE = "([^#]*)"

-- -------
-- request
-- -------
local METHOD = "^([%a]+)"
local URL = "([^#%s]*)"
local HTTP_VERSION = "([HTTP%/%.%d]*)"

local REQUEST = METHOD .. WS .. URL .. WS .. HTTP_VERSION .. WS .. REST

local methods =
	{ GET = "", HEAD = "", OPTIONS = "", TRACE = "", PUT = "", DELETE = "", POST = "", PATCH = "", CONNECT = "" }

function M:_parse_request(line)
	local lnum = self.cursor
	self.cursor = self.cursor + 1
	local req = self.r.request

	line = self.r:replace_variable(line, lnum)

	local ws1, ws2, ws3, rest, hv
	req.method, ws1, req.url, ws2, hv, ws3, rest = string.match(line, REQUEST)

	if not req.method then
		self.r:add_diag(ERR, "http method is missing or doesn't start with a letter", 0, 0, lnum)
		return line
	elseif ws1 == "" then
		local _, no_letter = string.match(line, "([%a]+)([^%s]?)")
		if no_letter and no_letter ~= "" then
			self.r:add_diag(ERR, "this is not a valid http method", 0, #req.method, lnum)
		else
			self.r:add_diag(ERR, "white space after http method is missing", 0, #req.method, lnum)
		end
		return line
	elseif req.url == "" then
		local msg = "url is missing"
		if methods[req.method] ~= "" then
			msg = "unknown http method and missing url"
		end
		self.r:add_diag(ERR, msg, 0, #req.method + #ws1 + #req.url, lnum)
		return line
	elseif #rest > 0 and not string.match(rest, "[%s]*#") then
		self.r:add_diag(
			INF,
			"invalid input after the request definition: '" .. rest .. "', maybe spaces?",
			0,
			#req.method + #ws1 + #req.url + #ws2 + #hv + #ws3,
			lnum
		)
	end

	if hv ~= "" then
		req.http_version = hv
	end

	if methods[req.method] ~= "" then
		self.r:add_diag(INF, "unknown http method", 0, #req.method, lnum)
	end

	if string.sub(req.url, 1, 4) ~= "http" then
		self.r:add_diag(ERR, "url must start with http", 0, #req.method, lnum)
	end

	self.r.meta.request = lnum

	return line
end

-- ---------
-- variables
-- ---------
local VKEY = "^@([%a][%w%-_%.]*)"
local VARIABLE = VKEY .. WS .. "([=]?)" .. WS .. VALUE .. REST

local configures = { insecure = "", raw = "", timeout = "", proxy = "", check_json_body = "" }

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
			local k, ws1, d, ws2, v, rest = string.match(line, VARIABLE)
			self.cursor = lnum + 1

			if not k then
				self.r:add_diag(ERR, "valid variable key is missing", 0, 1, lnum)
			elseif d == "" then
				self.r:add_diag(ERR, "variable delimiter is missing", 0, 1 + #k + #ws1, lnum)
			elseif v == "" then
				self.r:add_diag(ERR, "variable value is missing", 0, 1 + #k + #ws1 + #d + #ws2, lnum)
			elseif rest and rest ~= "" and not string.match(rest, "^#") then
				local col = 1 + #k + #ws1 + #d + #ws2 + #v
				self.r:add_diag(INF, "invalid input after the variable: " .. rest, 0, col, lnum)
			end

			if k and v ~= "" then
				local key = string.sub(k, 1, 4)
				if key == "cfg." and #k > 4 then
					key = string.sub(k, 5)
					if configures[key] ~= "" then
						self.r:add_diag(INF, "unknown configuration key", 0, #k, lnum)
					end
					self.r.request[key] = self.r:to_cfg_value(key, v, lnum)
				else
					v = self.r:replace_variable(v, lnum)
					self.r.variables[k] = vim.trim(v)
					self.r.meta.variables[k] = lnum
				end
			end
		end
	end

	-- on the end, means only variables or nothing found
	-- -> must be the global variables area
	return nil
end

-- -------------------
-- headers and queries
-- -------------------
local HQKEY = "([^=:%s]+)"
local HEADER_QUERY = HQKEY .. WS .. "([:=]?)" .. WS .. VALUE .. REST

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
			local k, ws1, d, ws2, v, rest = string.match(line, HEADER_QUERY)

			if d == "" then
				self.r:add_diag(ERR, "header: ':' or query: '=' delimiter is missing", 0, #k + #ws1, lnum)
			elseif v == "" then
				local kind = "header"
				if d == "=" then
					kind = "query"
				end
				self.r:add_diag(ERR, kind .. " value is missing", 0, #k + #ws1 + #d + #ws2, lnum)
			elseif rest and rest ~= "" and not string.match(rest, "^#") then
				local col = #k + #ws1 + #d + #ws2 + #v
				local kind = "header"
				if d == "=" then
					kind = "query"
				end
				self.r:add_diag(INF, "invalid input after the " .. kind .. ": " .. rest, 0, col, lnum)
			end

			if v ~= "" then
				v = self.r:replace_variable(v, lnum)
				v = vim.trim(v)

				if d == ":" then
					self.r.request.headers = self.r.request.headers or {}

					local val = self.r.request.headers[k]
					if val then
						self.r:add_diag(WRN, "overwrite header key: " .. k, 0, #k, lnum)
					end
					self.r.request.headers[k] = v
				else
					self.r.request.query = self.r.request.query or {}

					local val = self.r.request.query[k]
					if val then
						self.r:add_diag(WRN, "overwrite query key: " .. k, 0, #k, lnum)
					end
					self.r.request.query[k] = v
				end
			end
		end
	end
end

function M:_parse_json()
	local line, first_char = self:_ignore_lines()

	if not line or first_char ~= "{" then
		return line
	else
		local json_start = self.cursor
		local with_break = false

		for i = self.cursor + 1, self.len do
			line = self.lines[i]
			self.cursor = i

			-- until comment line or blank line
			if string.match(line, "^#") or string.match(line, "^%s*$") then
				with_break = true
				break
			end
		end

		local json_end = self.cursor
		if with_break then
			-- remove comment or empty line
			json_end = self.cursor - 1
		else
			self.cursor = self.cursor + 1
		end

		self.r.meta.body = { starts = json_start, ends = json_end }
		self.r.request.body = table.concat(self.lines, "", json_start, json_end)

		self.r:check_json_body_if_enabled(json_start, json_end)
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
				self.r.meta.script = { starts = start, ends = i - 1 }
				self.r.request.script = table.concat(self.lines, "\n", start, i - 1)
				self.cursor = self.cursor + 1
				return line
			end
		end

		self.r:add_diag(ERR, "missing end of script", 0, 0, self.cursor)
		return line
	end
end

function M:_parse_after_last()
	for i = self.cursor, self.len do
		local line = self.lines[i]
		local first_char = string.sub(line, 1, 1)

		if first_char == "" or first_char == "#" or line:match("^%s") then
			-- do nothing, comment or empty line
		else
			self.cursor = i
			self.r:add_diag(
				ERR,
				"invalid input, this and the following lines are ignored",
				0,
				#line,
				self.cursor,
				self.len
			)
			return line
		end
	end

	self.cursor = self.len
	return nil
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

M.get_replace_variable_str = function(lines, row, col)
	local key = nil
	for s, k, e in string.gmatch(lines[row], "(){{(.-)}}()") do
		if s - 1 <= col and e - 1 > col then
			key = k
			break
		end
	end

	-- early return, if not replacement exist in the current line
	if not key then
		return nil
	end

	local r = M.parse(lines, row, { is_in_execute_mode = false })
	local value = r.variables[key]

	-- resolve environment and exec variable
	if not value then
		value = r:replace_variable_by_key(key)
	end

	if value then
		local lnum_str = ""
		-- environment or exec variables have no line number
		local lnum = r.meta.variables[key]
		if lnum then
			lnum_str = "[" .. lnum .. "] "
		end
		return lnum_str .. key .. " = " .. value, lnum
	else
		local isPrompt = string.sub(key, 1, 1) == ":"
		if isPrompt == true then
			return "prompt variables are not supported for a preview"
		end

		if key == "" then
			return "no key found"
		end
		return "no value found for key: " .. key
	end
end

return M
