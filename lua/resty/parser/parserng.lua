local exec = require("resty.exec")
local util = require("resty.util")

local function info(column, msg)
	return { col = column, message = msg, severity = vim.diagnostic.severity.INFO }
end

local function err(column, msg)
	return { col = column, message = msg, severity = vim.diagnostic.severity.ERROR }
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
			if string.sub(lines[i], 1, 3) == "###" then
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

function M.new(input)
	return setmetatable({
		lines = util.input_to_lines(input),
		parsed = {},
	}, { __index = M })
end

function M.parse(input, selected)
	local start = os.clock()

	local p = M.new(input)
	p.parsed = {
		request = {
			query = {},
			headers = {},
		},
		variables = {},
		replacements = {},
	}

	selected = selected or 1
	if selected > #p.lines then
		-- error("the selected line: " .. selected .. " is greater then the given lines: " .. #p.lines, 0)
		selected = #p.lines
	elseif selected < 0 then
		selected = 1
	end

	local s, e = find_request(p.lines, selected)

	-- start > 1, means, there are global variables
	if s > 1 then
		p.cursor = 1
		p.len = s - 1
		p:_parse_variables()
	end

	local r = p:parse_request(s, e)

	r.duration = os.clock() - start

	return r
end

function M:parse_request(from, to)
	self.cursor = from
	self.len = to

	local parsers = {
		M._parse_variables,
		M._parse_method_url,
		M._parse_header_query,
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

	return self.parsed
end

local WS = "([%s]*)"
local WS1 = "([%s]+)"
local REST = WS .. "(.*)"

local REQ = "^([%w]+)" .. WS1 .. "([%w%d%_%.%?=&-:/{}]+)" .. WS .. "([HTTP%/%.%d]*)" .. REST

local methods =
	{ GET = "", HEAD = "", OPTIONS = "", TRACE = "", PUT = "", DELETE = "", POST = "", PATCH = "", CONNECT = "" }

function M._parse_line_method_url(line)
	local m, ws1, url, ws2, hv, ws3, comment = string.match(line, REQ)

	if not m then
		return nil, err(1, "http method is missing ")
	elseif not ws1 then
		return nil, err(#m, "white space after http method is missing ")
	elseif not url then
		return nil, err(#m + #ws1, "url is missing ")
	elseif comment and #comment > 0 and not string.match(comment, "[%s]*#") then
		return nil,
			info(#m + #ws1 + #url + #ws2 + #hv + #ws3, "invalid input after the request definition: " .. comment)
	end

	local r = { method = m, url = url }
	if hv ~= "" then
		r.http_version = hv
	end

	-- TODO:
	-- replace variables in url (and query)
	-- separate url and query
	-- separate the query parameter, if exist
	-- local query_start = string.find(url, "?")
	-- if query_start then
	-- 	local query = string.sub(url, query_start + 1)
	-- 	url = string.sub(url, 1, query_start - 1)
	-- 	r.request.query = {}
	-- 	for k, v in string.gmatch(query, "([^&=?]+)=([^&=?]+)") do
	-- 		r.request.query[k] = v
	-- 	end
	-- end

	if methods[m] ~= "" then
		return r, info(1, "unknown http method: " .. m)
	else
		return r, nil
	end
end

function M:_parse_method_url(line)
	self.cursor = self.cursor + 1
	line = M._replace_variable(line, self.parsed.variables, self.parsed.replacements)

	local req, e = M._parse_line_method_url(line)

	if req then
		self.parsed.request.method = req.method
		self.parsed.request.url = req.url

		if req.http_version and #req.http_version > 0 then
			self.parsed.request.http_version = req.http_version
		end
	else
		print("Error: " .. vim.inspect(e))
	end

	return line
end

local VARIABLE = "^@([%w%_-]+)" .. WS .. "([=]?)" .. WS .. "([^#^%s]*)" .. REST

function M._parse_line_variable(line)
	local k, ws1, eq, ws2, v, ws3, comment = string.match(line, VARIABLE)

	if not k or k == "" then
		return nil, nil, err(1, "variable key is missing")
	elseif not eq or eq == "" then
		return k, nil, err(#k + #ws1, "equal char is missing")
	elseif not v or v == "" then
		return k, nil, err(#k + #ws1 + #eq + #ws2, "variable value is missing")
	elseif comment and #comment > 0 and not string.match(comment, "[%s]*#") then
		local col = #k + #ws1 + #eq + #ws2 + #v + #ws3
		return k, v, info(col, "invalid input after the request definition: " .. comment)
	end

	return k, v, nil
end

function M:_parse_variables(_)
	return self:parse_matching_line("@", M._parse_line_variable, function(k, v)
		self.parsed.variables[k] = v
	end)
end

local WITH_COMMENT = "[#%.]*"

local HEADER = "^([%w][^%s^:^%#]*)[%s]*:[%s]*([^#]+)" .. WITH_COMMENT
local QUERY = "^([%w][^%s^=^%#]*)[%s]*=[%s]*([^#]+)" .. WITH_COMMENT

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

function M:_parse_header_query()
	return self:parse_matching_line("%w", M._phq, function(k, v, what)
		if what == 1 then
			self.parsed.request.headers[k] = v
		elseif what == 2 then
			self.parsed.request.query[k] = v
		end
	end)
end

function M:_parse_json(line)
	local l, body = self:_parse_body(line, "^{")
	if body then
		self.parsed.request.body = body
	end
	return l
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

		-- until blank line
		if string.match(line, "^%s*$") then
			self.cursor = i
			return line, table.concat(self.lines, "", start, i)
		-- until comment line
		elseif string.match(line, "^#") then
			self.cursor = i
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

		if first_char == "" or first_char == "#" or line:match("^%s") then
			-- do nothing, comment or empty line
		elseif string.match(first_char, match) then
			line = M._replace_variable(line, self.parsed.variables, self.parsed.replacements)
			collect_result(parser(line))
		else
			self.cursor = i
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
