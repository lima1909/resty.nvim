local exec = require("resty.exec")

local M = { global_variables = {} }

M.default_opts = {
	replace_variables = true, -- for completion, for a better performance (resty-cmp)
	is_prompt_supported = true, -- for diagnostics, by edit resty and http files
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
		-- use the possibility to use a cached value
		if key:sub(2, 2) == ">" then
			local value = M.global_variables[key]
			if value then
				return value, "cmd"
			end
			value = exec.cmd(key:sub(3))
			M.global_variables[key] = value
			return value, "cmd"
		end

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

function M:get_header(header)
	for _, h in ipairs(self.request.headers) do
		if h == header then
			return h
		end
	end

	return nil
end

function M:is_valid_variable_row(row)
	if row >= self.meta.area.starts and row <= self.meta.area.ends then
		if self.meta.request then
			return self.meta.request > row
		elseif self.meta.body then
			return self.meta.body.starts > row
		elseif self.meta.script then
			return self.meta.script.starts > row
		end

		-- NOTE: maybe check start of headers and query too?
		return true
	end

	return false
end

function M:is_valid_headers_row(row)
	if not self.meta.request then
		return false
	end

	if self.meta.request < row and row <= self.meta.area.ends then
		if self.meta.body then
			return self.meta.body.starts > row
		elseif self.meta.script then
			-- starts - 1 is position of '--{%'
			return self.meta.script.starts - 1 > row
		end

		-- NOTE: maybe check start of headers and query too?
		return true
	end

	return false
end

function M:write_to_buffer(bufnr)
	local req = self.request

	-- QUERY
	local query_str = ""
	for key, value in pairs(req.query) do
		if query_str:len() == 0 then
			query_str = "?" .. key .. "=" .. vim.trim(value)
		else
			query_str = query_str .. "&" .. key .. "=" .. vim.trim(value)
		end
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"## Request:",
		"",
		"```http",
		req.method .. " " .. req.url .. query_str,
	})

	-- HEADERS
	for key, value in pairs(req.headers) do
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { key .. ": " .. value })
	end

	-- BODY
	if req.body then
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, vim.split(req.body, "\n"))
	end

	-- SCRIPT
	if req.script then
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "# @lang=lua", "> {%" })
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, vim.split(req.script, "\n"))
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "%}" })
	end

	vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "```" })

	-- VARIABLES and REPLACEMENTS
	if #self.replacements > 0 then
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
			"",
			"## Variables:",
			"",
		})
		for _, typ in ipairs(self.replacements) do
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
				"- '" .. typ.from .. "': '" .. typ.to .. "' (" .. typ.type .. ")",
			})
		end
	end

	-- GLOBAL VARIABLES
	local with = true
	for key, value in pairs(M.global_variables) do
		if with then
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
				"",
				"## Global Variables:",
				"",
			})
			with = false
		end
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
			"- '" .. key .. "': '" .. value .. "'",
		})
	end
end

return M
