local M = {}

M.varcfg = {
	-- curl configuration
	{
		label = "insecure",
		labelDetails = { detail = "boolean", description = "" },
		insertText = "@cfg.insecure = true",
		filterText = "@cfg.insecure=true",
		documentation = {
			kind = "markdown",
			value = "allow insecure server connections\nset value to: *true*",
		},
		cmp = { kind_hl_group = "Structure", kind_text = "Curl" },
	},
	{
		label = "raw",
		labelDetails = { detail = "string", description = "" },
		insertText = "@cfg.raw = ",
		filterText = "@cfg.raw",
		documentation = {
			kind = "markdown",
			value = "any additonal curl args, it must be an comma seperated list\nfor example: *--insecure,--verbose,--fail*",
		},
		cmp = { kind_hl_group = "Structure", kind_text = "Curl" },
	},
	{
		label = "dry_run",
		labelDetails = { detail = "boolean", description = "" },
		insertText = "@cfg.dry_run = true",
		filterText = "@cfg.dry_run=true",
		documentation = {
			kind = "markdown",
			value = "whether to return the args to be ran through curl\nset value to: *true*",
		},
		cmp = { kind_hl_group = "Structure", kind_text = "Curl" },
	},
	{
		label = "timeout",
		labelDetails = { detail = "number", description = "" },
		insertText = "@cfg.timeout = 1000",
		filterText = "@cfg.timeout",
		documentation = {
			kind = "markdown",
			value = "request timeout in mseconds\nset value to: *1000* (1 second)",
		},
		cmp = { kind_hl_group = "Structure", kind_text = "Curl" },
	},
	{
		label = "proxy",
		labelDetails = { detail = "string", description = "" },
		insertText = "@cfg.proxy = ",
		filterText = "@cfg.proxy",
		documentation = {
			kind = "markdown",
			value = "use this proxy: '[protocol://]host[:port]'",
		},
		cmp = { kind_hl_group = "Structure", kind_text = "Curl" },
	},
	-- resty request configuration
	{
		label = "check_json_body",
		labelDetails = { detail = "boolean", description = "" },
		insertText = "@cfg.check_json_body = true",
		filterText = "@cfg.check_json_body=true",
		documentation = {
			kind = "markdown",
			value = "check the reques body if it is a valid JSON\nset value to: *true*",
		},
		cmp = { kind_hl_group = "Function", kind_text = "Resty" },
	},
}

M.headers = {
	{
		label = "accept: */*",
		insertText = "Accept: */*",
		cmp = { kind_hl_group = "Function", kind_text = "Headers" },
	},
	{
		label = "accept: application/json",
		insertText = "Accept: application/json",
		cmp = { kind_hl_group = "Function", kind_text = "Headers" },
	},
	{
		label = "accept: text/html",
		insertText = "Accept: text/html",
		cmp = { kind_hl_group = "Function", kind_text = "Headers" },
	},

	{
		label = "accept-charset: utf-8",
		insertText = "Accept-Charset: utf-8",
		cmp = { kind_hl_group = "Function", kind_text = "Headers" },
	},

	{
		label = "authorization: basic",
		insertText = "Authorization: Basic ",
		cmp = { kind_hl_group = "Function", kind_text = "Headers" },
	},
	{
		label = "authorization: Bearer",
		insertText = "Authorization: Bearer ",
		cmp = { kind_hl_group = "Function", kind_text = "Headers" },
	},
	{
		label = "content-type: text/plain",
		insertText = "Content-Type: text/plain",
		cmp = { kind_hl_group = "Function", kind_text = "Headers" },
	},
	{
		label = "content-type: application/json ",
		insertText = "Content-Type: application/json",
		cmp = { kind_hl_group = "Function", kind_text = "Headers" },
	},
	{
		label = "cache-control: no-cache",
		insertText = "Cache-Control: no-cache",
		cmp = { kind_hl_group = "Function", kind_text = "Headers" },
	},
	{
		label = "connection: keep-alive",
		insertText = "Connection: keep-alive",
		cmp = { kind_hl_group = "Function", kind_text = "Headers" },
	},
	{
		label = "content-length: ",
		insertText = "Content-Length: ",
		cmp = { kind_hl_group = "Function", kind_text = "Headers" },
	},
	{
		label = "accept-encoding: gzip",
		insertText = "Accept-Encoding: gzip",
		cmp = { kind_hl_group = "Function", kind_text = "Headers" },
	},
}

M.request = {
	{ label = "GET http://", cmp = { kind_hl_group = "Constant", kind_text = "Request" } },
	{ label = "GET https://", cmp = { kind_hl_group = "Constant", kind_text = "Request" } },
	{ label = "POST http://", cmp = { kind_hl_group = "Constant", kind_text = "Request" } },
	{ label = "POST https://", cmp = { kind_hl_group = "Constant", kind_text = "Request" } },
}

M.available_headers = function(headers)
	if not headers then
		return M.headers
	end

	local entries = {}
	for _, h in ipairs(M.headers) do
		local key = string.match(h.insertText, "([^:%s]+)")
		if key and not headers[key] then
			table.insert(entries, h)
		end
	end

	return entries
end

-- compute the available configurations: M.varcfg - variables
M.available_varcfg = function(variables)
	if not variables then
		return M.varcfg
	end

	-- add not used configs
	local entries = {}

	for _, varcfg in ipairs(M.varcfg) do
		if not variables[varcfg.label] then
			table.insert(entries, varcfg)
		end
	end

	return entries
end

return M
