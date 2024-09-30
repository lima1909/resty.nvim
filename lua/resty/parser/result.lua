local exec = require("resty.exec")

local M = { global_variables = {} }

M.new = function()
	return setmetatable({
		-- ast = { request = {} },
		request = { query = {}, headers = {} },
		variables = {},
		replacements = {},
		diagnostics = {},
		parse_duration = 0,
	}, { __index = M })
end

function M:has_diag()
	return #self.diagnostics > 0
end

function M:add_diag(sev, msg, col, end_col, lnum, end_lnum)
	table.insert(self.diagnostics, {
		col = col,
		end_col = end_col,
		lnum = lnum - 1, -- NOTE: lnum is 0 indexed, end readed_lines starts by 1
		end_lnum = end_lnum,
		message = msg,
		severity = sev,
	})

	return self
end

function M:replace_variables()
	if next(self.variables) == nil then
		self.duration = self.parse_duration
		return self
	end

	local start = os.clock()

	if not self.request.url then
		-- error("no request URL found between row: " .. s .. " and " .. e, 0)
		error("no request URL found between row: ", 0)
	end

	-- replace variables in variables-values
	for k, v in pairs(self.variables) do
		self.variables[k] = self:_replace_variable(v)
	end

	-- replace variables in url
	self.request.url = self:_replace_variable(self.request.url)

	-- replace variables in query-values
	for k, v in pairs(self.request.query) do
		self.request.query[k] = self:_replace_variable(v)
	end

	-- replace variables in headers-values
	for k, v in pairs(self.request.headers) do
		self.request.headers[k] = self:_replace_variable(v)
	end

	self.duration = (os.clock() - start) + self.parse_duration
	return self
end

function M:_replace_variable(line)
	return string.gsub(line, "{{(.-)}}", function(key)
		local value
		local symbol = key:sub(1, 1)

		-- environment variable
		if symbol == "$" then
			value = os.getenv(key:sub(2):upper())
			table.insert(self.replacements, { from = key, to = value, type = "env" })
		-- commmand
		elseif symbol == ">" then
			value = exec.cmd(key:sub(2))
			table.insert(self.replacements, { from = key, to = value, type = "cmd" })
		-- prompt
		elseif symbol == ":" then
			value = vim.fn.input("Input for key " .. key:sub(2) .. ": ")
			table.insert(self.replacements, { from = key, to = value, type = "prompt" })
		-- variable
		else
			value = self.variables[key]
			if value then
				table.insert(self.replacements, { from = key, to = value, type = "var" })
			else
				value = M.global_variables[key]
				if not value then
					-- TODO: replace this error
					error("invalid variable key: " .. key, 0)
				end
				table.insert(self.replacements, { from = key, to = value, type = "global_var" })
			end
		end

		return value
	end)
end

return M
