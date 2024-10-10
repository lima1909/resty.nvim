local exec = require("resty.exec")

local M = { global_variables = {} }

M.new = function(replace_variables)
	return setmetatable({
		request = { query = {}, headers = {} },
		variables = {},
		replacements = {},
		diagnostics = {},
		meta = { area = {}, variables = {} },
		cfg = { replace_variables = replace_variables },
	}, { __index = M })
end

function M:has_diag()
	return #self.diagnostics > 0
end

function M:add_diag(sev, msg, col, end_col, lnum, end_lnum)
	if end_lnum and end_lnum > 1 then
		end_lnum = end_lnum - 1
	end

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

function M:replace_variable(line, lnum)
	if self.cfg.replace_variables == false then
		return line
	end

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
					self:add_diag(vim.diagnostic.severity.ERROR, "invalid variable key: " .. key, 0, 0, lnum or 1)
				end
				table.insert(self.replacements, { from = key, to = value, type = "global_var" })
			end
		end

		return value
	end)
end

return M
