local exec = require("resty.exec")

local M = { global_variables = {} }

M.default_opts = {
	replace_variables = true,
	is_prompt_supported = true,
}

M.new = function(opts)
	return setmetatable({
		request = { query = {}, headers = {} },
		variables = {},
		replacements = {},
		diagnostics = {},
		meta = { area = {}, variables = {} },
		opts = vim.tbl_deep_extend("force", M.default_opts, opts or {}),
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

function M:check_json_body_if_enabled(lnum, end_lnum)
	if self.request["check_json_body"] == "true" then
		local ok, err = pcall(vim.json.decode, self.request.body, {})
		if ok == false then
			self:add_diag(vim.diagnostic.severity.ERROR, "json parsing error: " .. err, 0, 0, lnum, end_lnum)
		end
	end
end

function M:replace_variable_by_key(key)
	local symbol = key:sub(1, 1)

	-- environment variable
	if symbol == "$" then
		return os.getenv(key:sub(2):upper()), "env"
	-- commmand
	elseif symbol == ">" then
		return exec.cmd(key:sub(2)), "cmd"
	-- prompt
	elseif symbol == ":" then
		if self.opts.is_prompt_supported == false then
			return nil, "prompt"
		end
		return vim.fn.input("Input for key " .. key:sub(2) .. ": "), "prompt"
	-- variable
	else
		local value = self.variables[key]
		if value then
			return value, "var"
		else
			value = M.global_variables[key]
			if value then
				return value, "global_var"
			end
		end
	end

	return nil
end

function M:replace_variable(line, lnum)
	if self.opts.replace_variables == false then
		return line
	end

	return string.gsub(line, "{{(.-)}}", function(key)
		local value, type = self:replace_variable_by_key(key)
		if value then
			table.insert(self.replacements, { from = key, to = value, type = type })
		elseif type == "prompt" then
			-- ignore prompt
		elseif key == "" then
			self:add_diag(vim.diagnostic.severity.ERROR, "no key found", 0, 1000, lnum or 1)
		else
			self:add_diag(vim.diagnostic.severity.ERROR, "no value found for key: " .. key, 0, 1000, lnum or 1)
		end

		return value
	end)
end

return M
