local result = require("resty.parser.result")
local util = require("resty.util")

local ERR = vim.diagnostic.severity.ERROR

local M = {}

M.parse_curl_cmd = function(curl_cmd_lines, start_line, r)
	return M.new(curl_cmd_lines, start_line, r):parse_cmd()
end

M.new = function(curl_cmd_lines, start_line, r)
	start_line = start_line or 1
	r = r or result.new({})
	r.meta = { curl = { starts = start_line } }

	local lines = util.input_to_lines(curl_cmd_lines)

	local p = setmetatable({
		c = 1, -- cursor
		lines = lines,
		current_line_nr = start_line,
		current_line = lines[start_line],
		r = r,
	}, { __index = M })

	return p
end

function M:parse_cmd()
	if self.current_line:sub(1, 4) ~= "curl" then
		self.r:add_diag(ERR, "command starts not with 'curl'", 1, 4, self.current_line_nr)
		return self.r
	end

	-- start by 5: after 'curl'
	self.c = 4

	-- while not on the end or not blank line
	while self.current_line and not string.match(self.current_line, "^%s*$") do
		self.r.meta.curl.ends = self.current_line_nr

		while self.c <= #self.current_line do
			local c = self:next()

			-- find options (args)
			if c == "-" then
				c = self:next()

				-- METHOD
				if c == "X" then
					self:ignore_whitspace()
					self.r.request.method = self:next_until(" "):upper()
				-- HEADERS
				elseif c == "H" then
					self.r.request.headers = self:header()
				-- BODY
				elseif c == "d" then
					self.r.request.body = self:body()
				-- arguments with two dashes
				elseif c == "-" then
					local arg = self:next_until(" ")
					-- RAW arguments
					if arg == "insecure" then
						self.r.request.insecure = true
					elseif arg == "header" then
						self.r.request.headers = self:header()
					elseif arg == "request" then
						self:ignore_whitspace()
						self.r.request.method = self:next_until(" "):upper()
					-- BODY
					elseif arg == "data-raw" or arg == "data" or arg == "json" then
						self.r.request.body = self:body()
					end
				end
			-- find URL http or https
			elseif (c == "'" or c == "h") and self:peek(9):match("ttp[s]?://") then
				self:one_step_back()
				self.r.request.url = self:between()
			end
		end

		self.current_line_nr = self.current_line_nr + 1
		self.current_line = self.lines[self.current_line_nr]
		self.c = 1
	end -- not blank line

	self.r.request.method = self.r.request.method or "GET"

	if not self.r.url then
		self.r:add_diag(ERR, "no url found", 0, self.c, self.r.meta.curl.starts, self.r.meta.curl.ends)
	end

	return self.r
end

-- one step back
-- if you want use a characters, which is already consumed
function M:one_step_back()
	self.c = self.c - 1
end

function M:peek(pos)
	pos = pos or 1
	return self.current_line:sub(self.c, self.c + pos - 1)
end

function M:next(pos)
	pos = pos or 1
	local r = self:peek(pos)
	self.c = self.c + pos
	return r
end

function M:ignore_whitspace()
	while self.c <= #self.current_line do
		local c = self:next(1)
		if not c:match("%s") then
			self.c = self.c - 1
			return c
		end
	end
end

local found = true
local not_found = false

function M:next_until(char)
	local pos = self.c

	while pos <= #self.current_line do
		local c = self.current_line:sub(pos, pos)
		if c == char then
			local r = self:next(pos - self.c)
			self.c = self.c + 1
			return r, found
		end
		pos = pos + 1
	end

	-- not found, return the full string
	return self:next(pos - self.c), not_found
end

function M:between()
	local r, ok

	self:ignore_whitspace()
	local c = self:next(1)

	if c == "'" then
		r, ok = self:next_until("'")
	elseif c == '"' then
		r, ok = self:next_until('"')
	else
		self:one_step_back()
		r, _ = self:next_until(" ")
		ok = true -- always ok, to read until the end of the input, without closing space
	end

	if not ok then
		self.r:add_diag(
			ERR,
			"could not found termination character: " .. c .. " " .. tostring(r),
			0,
			self.c,
			self.current_line_nr
		)
	end

	return r
end

function M:header()
	local header = self:between()
	if header then
		local pos = header:find(":")
		local k, v = header:sub(1, pos - 1), header:sub(pos + 1)
		self.r.request.headers = self.r.request.headers or {}
		self.r.request.headers[vim.trim(k)] = vim.trim(v)
		return self.r.request.headers
	else
		self.r:add_diag(ERR, "missing header", 0, self.c, self.current_line_nr)
	end
end

function M:body()
	self:ignore_whitspace()
	local body = self:between()
	if body then
		return body
	else
		self.r:add_diag(ERR, "missing body", 0, self.c, self.current_line_nr)
	end
end

return M
