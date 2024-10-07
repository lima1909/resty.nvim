local M = {}

M.var_cfg = {
	-- curl configuration
	{
		label = "@cfg.insecure",
		labelDetails = { detail = "boolean", description = "" },
		insertText = "@cfg.insecure = true",
		documentation = {
			kind = "markdown",
			value = "allow insecure server connections",
		},
		cmp = { kind_hl_group = "Structure", kind_text = "curl" },
	},
	{
		label = "@cfg.dry_run",
		labelDetails = { detail = "boolean", description = "" },
		insertText = "@cfg.dry_run = true",
		documentation = {
			kind = "markdown",
			value = "whether to return the args to be ran through curl",
		},
		cmp = { kind_hl_group = "Structure", kind_text = "curl" },
	},
	{
		label = "@cfg.timeout",
		labelDetails = { detail = "number", description = "" },
		insertText = "@cfg.timeout = 1000",
		documentation = {
			kind = "markdown",
			value = "request timeout in mseconds",
		},
		cmp = { kind_hl_group = "Structure", kind_text = "curl" },
	},
	{
		label = "@cfg.proxy",
		labelDetails = { detail = "string", description = "" },
		insertText = "@cfg.proxy = ",
		documentation = {
			kind = "markdown",
			value = "use this proxy: '[protocol://]host[:port]'",
		},
		cmp = { kind_hl_group = "Structure", kind_text = "curl" },
	},
	-- resty request configuration
	{
		label = "@cfg.check_json_body",
		labelDetails = { detail = "boolean", description = "" },
		insertText = "@cfg.check_json_body = true",
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
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},
	{
		label = "accept: application/json",
		insertText = "Accept: application/json",
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},
	{
		label = "accept: text/html",
		insertText = "Accept: text/html",
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},

	{
		label = "accept-charset: utf-8",
		insertText = "Accept-Charset: utf-8",
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},

	{
		label = "authorization: basic",
		insertText = "Authorization: Basic ",
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},
	{
		label = "authorization: Bearer",
		insertText = "Authorization: Bearer ",
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},
	{
		label = "content-type: text/plain",
		insertText = "Content-Type: text/plain",
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},
	{
		label = "content-type: application/json ",
		insertText = "Content-Type: application/json",
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},
	{
		label = "cache-control: no-cache",
		insertText = "Cache-Control: no-cache",
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},
	{
		label = "connection: keep-alive",
		insertText = "Connection: keep-alive",
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},
	{
		label = "content-length: ",
		insertText = "Content-Length: ",
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},
	{
		label = "accept-encoding: gzip",
		insertText = "Accept-Encoding: gzip",
		cmp = { kind_hl_group = "Function", kind_text = "resty" },
	},
}

return M
