local util = require("resty.util")
local result = require("resty.parser.result")
local curl_cmd = require("resty.parser.curl")

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
	local start = vim.loop.hrtime()

	local parser = M.new(input, selected, opts)
	local s, e = parser:find_area()

	-- start > 1, means, there are global variables
	if s > 1 then
		parser.cursor = 1
		parser.len = s - 1
		parser:_parse_variables(nil, true)
	end

	parser:parse_definition(s, e)

	parser.r.duration = vim.loop.hrtime() - start
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

	local parsers = nil

	-- check, the current line: a request or a curl command
	if line:sub(1, 5) == ">curl" then
		parsers = {
			M._parse_curl_command,
			M._parse_script,
			M._parse_after_last,
		}
	else
		parsers = {
			M._parse_request,
			M._parse_headers_queries,
			M._parse_json_body,
			M._parse_script,
			M._parse_after_last,
		}
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

function M:_parse_curl_command(line)
	local curl = curl_cmd.new(self.r)
	self.r.meta.curl = { starts = self.cursor, ends = self.cursor }

	curl.c = 5 -- cut: '>curl'
	curl:parse_line(line, self.cursor)
	self.cursor = self.cursor + 1

	for lnum = self.cursor, self.len do
		line = self.lines[lnum]

		-- an empty line, then stop
		if string.match(line, "^%s*$") then
			self.cursor = lnum
			return line
		else
			self.r.meta.curl.ends = lnum
			self.cursor = lnum
			curl.c = 1
			curl:parse_line(line, lnum)
		end
	end
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
	local req = self.r.request

	line = self.r:replace_variable(line, self.cursor)

	local method, ws1, url, ws2, hv, ws3, rest = string.match(line, REQUEST)

	if not method then
		self.r:add_diag(ERR, "http method is missing or doesn't start with a letter", 0, 0, self.cursor)
		return line
	elseif ws1 == "" then
		local _, no_letter = string.match(line, "([%a]+)([^%s]?)")
		if no_letter and no_letter ~= "" then
			self.r:add_diag(ERR, "this is not a valid http method", 0, #method, self.cursor)
		else
			self.r:add_diag(ERR, "white space after http method is missing", 0, #method, self.cursor)
		end
		return line
	elseif url == "" then
		local msg = "url is missing"
		if methods[method] ~= "" then
			msg = "unknown http method and missing url"
		end
		self.r:add_diag(ERR, msg, 0, #method + #ws1 + #url, self.cursor)
		return line
	elseif #rest > 0 and not string.match(rest, "[%s]*#") then
		self.r:add_diag(
			INF,
			"invalid input after the request definition: '" .. rest .. "', maybe spaces?",
			0,
			#method + #ws1 + #url + #ws2 + #hv + #ws3,
			self.cursor
		)
	end

	if hv ~= "" then
		req.http_version = hv
	end

	if methods[method] ~= "" then
		self.r:add_diag(INF, "unknown http method", 0, #method, self.cursor)
	end

	if string.sub(url, 1, 4) ~= "http" then
		self.r:add_diag(ERR, "url must start with http", 0, #method + #ws1 + #url, self.cursor)
	end

	req.method = method
	req.url = url
	self.r.meta.request = self.cursor
	self.cursor = self.cursor + 1

	return line
end

-- ---------
-- variables
-- ---------
local VKEY = "^@([%a][%w%-_%.]*)"
local VARIABLE = VKEY .. WS .. "([=]?)" .. WS .. VALUE .. REST

local configures = { insecure = "", raw = "", timeout = "", proxy = "", dry_run = "", check_json_body = "" }

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

					if not self.r.meta.variables.starts then
						self.r.meta.variables.starts = lnum
						self.r.meta.variables.ends = lnum
					else
						self.r.meta.variables.ends = lnum
					end
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

				-- add meta for headers and query
				if not self.r.meta.headers_query.starts then
					self.r.meta.headers_query.starts = lnum
					self.r.meta.headers_query.ends = lnum
				else
					self.r.meta.headers_query.ends = lnum
				end
			end
		end
	end
end

M._file_path_buffer = ""

function M:_parse_json_body()
	local line, first_char = self:_ignore_lines()

	if not line or (first_char ~= "{" and first_char ~= "<") then
		return line
	-- json comes from a file
	elseif first_char == "<" then
		local fp = vim.trim(line:sub(2))
		if fp == M._file_path_buffer or vim.loop.fs_stat(fp) then
			M._file_path_buffer = fp
			self.r.meta.body = { starts = self.cursor, ends = self.cursor, from_file = true }
			self.r.request.body = fp
		else
			self.r:add_diag(ERR, "file not found: " .. fp, 0, #line, self.cursor)
		end

		self.cursor = self.cursor + 1
		return self.lines[self.cursor]
	-- json comes as json-string
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

		self.r.meta.body = { starts = json_start, ends = json_end, from_file = false }
		self.r.request.body = table.concat(self.lines, "", json_start, json_end)

		self.r:check_json_body_if_enabled(json_start, json_end)
	end

	return line
end

function M:_parse_script()
	local line, _ = self:_ignore_lines()

	-- resty: '--{%' and '--%}' or treesitter-http: '> {%' and  '%}'
	if line and (string.match(line, "^--{%%%s*$") or string.match(line, "^>%s{%%%s*$")) then
		-- ignore this line
		self.cursor = self.cursor + 1
		local start = self.cursor

		for i = start, self.len do
			line = self.lines[i]
			self.cursor = i

			if string.match(line, "^--%%}%s*$") or string.match(line, "^%%}%s*$") then
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

	return line
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
