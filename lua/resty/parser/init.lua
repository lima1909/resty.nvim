local kv = require("resty.parser.key_value")
local mu = require("resty.parser.method_url")
local b = require("resty.parser.body")
local d = require("resty.parser.delimiter")
local v = require("resty.parser.variables")
local util = require("resty.util")

local M = { global_variables = {} }
M.__index = M

M.set_global_variables = function(gvars)
	M.global_variables = vim.tbl_deep_extend("force", M.global_variables, gvars)
end

M.STATE_START = {
	id = 1,
	name = "start",
}

M.STATE_VARIABLE = {
	id = 2,
	name = "variables",
	parser = kv.parse_variable,
	set_result = function(slf, r)
		slf.variables[r.k] = r.v
	end,
}

M.STATE_METHOD_URL = {
	id = 3,
	name = "method and url",
	parser = mu.parse_method_url,
	set_result = function(slf, r)
		slf.request.method = r.method
		slf.request.url = r.url
	end,
}

M.STATE_HEADERS_QUERY = {
	id = 4,
	name = "header or query",
	parser = kv.parse_headers_query,
	set_result = function(slf, r)
		if r.delimiter == "=" then
			slf.request.query[r.k] = r.v
		else
			slf.request.headers[r.k] = r.v
		end
	end,
}

M.STATE_BODY = {
	id = 5,
	name = "body",
	parser = b.parse_request_body,
	set_result = function(slf, r)
		slf.request.body = (slf.request.body or "") .. r .. "\n"
	end,
}

M.STATE_SCRIPT = {
	id = 6,
	name = "script",
	parser = b.parse_script_body,
	set_result = function(slf, r)
		slf.request.script = (slf.request.script or "") .. r .. "\n"
	end,
}

local transitions = {
	[M.STATE_START.id] = { M.STATE_VARIABLE, M.STATE_METHOD_URL },
	[M.STATE_VARIABLE.id] = { M.STATE_VARIABLE, M.STATE_METHOD_URL },
	[M.STATE_METHOD_URL.id] = { M.STATE_BODY, M.STATE_HEADERS_QUERY, M.STATE_SCRIPT },
	[M.STATE_HEADERS_QUERY.id] = { M.STATE_BODY, M.STATE_HEADERS_QUERY, M.STATE_SCRIPT },
	[M.STATE_BODY.id] = { M.STATE_BODY, M.STATE_SCRIPT },
	[M.STATE_SCRIPT.id] = { M.STATE_SCRIPT, M.STATE_BODY },
}

function M:parse_line(parser, line, set_result)
	local no_error, result = pcall(parser, line)

	-- if has an error
	if not no_error then
		self:add_error(result)
		return true
	elseif result then
		set_result(self, result)
		return true
	end
end

function M:do_transition(line)
	local ts = transitions[self.current_state.id]
	for _, s in ipairs(ts) do
		if self:parse_line(s.parser, line, s.set_result) then
			self.current_state = s
			return
		end
	end
	--
	-- no valid transition found
	local err = "from current state: '" .. self.current_state.name .. "' are only possible state(s): "
	for _, s in ipairs(ts) do
		err = err .. s.name .. ", "
	end
	self:add_error(err:sub(1, #err - 2))
end

function M:has_errors()
	return self.errors ~= nil and #self.errors > 0
end

function M:add_error(message)
	table.insert(self.errors, {
		col = 0,
		lnum = self.readed_lines - 1, -- NOTE: lnum is 0 indexed, end readed_lines starts by 1
		severity = vim.diagnostic.severity.ERROR,
		message = message,
	})
	return self
end

---@param variables { } the parsed variables
---@param line string the input line
---@return string the output line with replaced variables
function M:replace_variable(variables, line, replacements)
	local ok, result = pcall(v.replace_variable, variables, line, replacements, M.global_variables)
	if not ok then
		self:add_error(result)
		return ""
	end

	return result
end

---@param line  string the readed line
---@param parse function a parser function
---@param with_replace_variable? boolean with replacing variables
---@return boolean has_parsed is the given a line, that the parser should parse
function M:read_line(line, parse, with_replace_variable)
	with_replace_variable = with_replace_variable or false

	-- ignore line with comment or empty line, do nothing
	if vim.startswith(line, "#") or line == "" or vim.trim(line) == "" then
		return false
	end

	-- cut comment from the current line
	local pos = string.find(line, "#")
	if pos then
		line = line:sub(1, pos - 1)
	end

	-- replace variables
	if with_replace_variable then
		line = self:replace_variable(self.variables, line, self.replacements)
		if line == "" then
			return false
		end
	end

	parse(self, line)

	return true
end

function M.new()
	local p = {
		current_state = M.STATE_START,
		readed_lines = 1,
		duration = 0,
		variables = {},
		replacements = {},
		request = {
			headers = {},
			query = {},
		},
		errors = {},
	}
	return setmetatable(p, M)
end

---Entry point, the parser
---@param input string | { } a string with delimiter '\n' or an array with strings
---@param selected? number the selected row
---@return self the parser with the request and possible errors
function M.parse(input, selected)
	selected = selected or 1
	local start_time = os.clock()

	local lines = util.input_to_lines(input)
	local p = M.new()
	--
	-- find request
	local ok, req_start, req_end = pcall(d.find_request, lines, selected)
	if not ok then
		return p:add_error(req_start)
	end

	-- start == 1, no global variables exist
	if req_start > 1 then
		-- read global variables
		while true do
			local line = lines[p.readed_lines]
			if not line or vim.startswith(line, "###") then
				break
			end

			p:read_line(line, function(_, l)
				local no_error, result = pcall(kv.parse_variable, l)
				if not no_error then
					p:add_error(result)
				elseif result then
					p.variables[result.k] = result.v
				end
			end)

			p.readed_lines = p.readed_lines + 1
		end
	end

	-- read request
	p.readed_lines = req_start
	while true do
		-- read the line and execute the state machine
		p:read_line(lines[p.readed_lines], M.do_transition, true)

		if p.readed_lines == req_end then
			break
		end
		p.readed_lines = p.readed_lines + 1
	end

	if not p.request.method or not p.request.url then
		p:add_error("a valid request expect at least a url (parse rows: " .. req_start .. ":" .. req_end .. ")")
	end

	p.duration = os.clock() - start_time
	return p
end

return M
