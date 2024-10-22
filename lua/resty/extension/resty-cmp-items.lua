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
			value = "allow insecure server connections",
		},
		cmp = { kind_hl_group = "Structure", kind_text = "curl" },
	},
	{
		label = "raw",
		labelDetails = { detail = "string", description = "" },
		insertText = "@cfg.raw = ",
		filterText = "@cfg.raw",
		documentation = {
			kind = "markdown",
			value = "any additonal curl args, it must be an comma seperated list.",
		},
		cmp = { kind_hl_group = "Structure", kind_text = "curl" },
	},
	-- {
	-- 	label = "dry_run",
	-- 	labelDetails = { detail = "boolean", description = "" },
	-- 	insertText = "@cfg.dry_run = true",
	-- 	filterText = "@cfg.dry_run=true",
	-- 	documentation = {
	-- 		kind = "markdown",
	-- 		value = "whether to return the args to be ran through curl",
	-- 	},
	-- 	cmp = { kind_hl_group = "Structure", kind_text = "curl" },
	-- },
	{
		label = "timeout",
		labelDetails = { detail = "number", description = "" },
		insertText = "@cfg.timeout = 1000",
		filterText = "@cfg.timeout",
		documentation = {
			kind = "markdown",
			value = "request timeout in mseconds",
		},
		cmp = { kind_hl_group = "Structure", kind_text = "curl" },
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
		cmp = { kind_hl_group = "Structure", kind_text = "curl" },
	},
	-- resty request configuration
	{
		label = "check_json_body",
		labelDetails = { detail = "boolean", description = "" },
		insertText = "@cfg.check_json_body = true",
		filterText = "@cfg.check_json_body=true",
		documentation = {
			kind = "markdown",
			value = "check the reques body if it is a valid JSON",
		},
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},
}

M.headers = {
	{
		label = "accept: */*",
		insertText = "Accept: */*",
		cmp = { kind_hl_group = "Function", kind_text = "headers" },
	},
	{
		label = "accept: application/json",
		insertText = "Accept: application/json",
		cmp = { kind_hl_group = "Function", kind_text = "headers" },
	},
	{
		label = "accept: text/html",
		insertText = "Accept: text/html",
		cmp = { kind_hl_group = "Function", kind_text = "headers" },
	},

	{
		label = "accept-charset: utf-8",
		insertText = "Accept-Charset: utf-8",
		cmp = { kind_hl_group = "Function", kind_text = "headers" },
	},

	{
		label = "authorization: basic",
		insertText = "Authorization: Basic ",
		cmp = { kind_hl_group = "Function", kind_text = "headers" },
	},
	{
		label = "authorization: Bearer",
		insertText = "Authorization: Bearer ",
		cmp = { kind_hl_group = "Function", kind_text = "headers" },
	},
	{
		label = "content-type: text/plain",
		insertText = "Content-Type: text/plain",
		cmp = { kind_hl_group = "Function", kind_text = "headers" },
	},
	{
		label = "content-type: application/json ",
		insertText = "Content-Type: application/json",
		cmp = { kind_hl_group = "Function", kind_text = "headers" },
	},
	{
		label = "cache-control: no-cache",
		insertText = "Cache-Control: no-cache",
		cmp = { kind_hl_group = "Function", kind_text = "headers" },
	},
	{
		label = "connection: keep-alive",
		insertText = "Connection: keep-alive",
		cmp = { kind_hl_group = "Function", kind_text = "headers" },
	},
	{
		label = "content-length: ",
		insertText = "Content-Length: ",
		cmp = { kind_hl_group = "Function", kind_text = "headers" },
	},
	{
		label = "accept-encoding: gzip",
		insertText = "Accept-Encoding: gzip",
		cmp = { kind_hl_group = "Function", kind_text = "headers" },
	},
}

M.available_headers = function(headers)
	local entries = {}
	for _, h in ipairs(M.headers) do
		local key = string.match(h.insertText, "([^:%s]+)")
		if key and not headers[key] then
			table.insert(entries, h)
		end
	end

	return entries
end

return M
