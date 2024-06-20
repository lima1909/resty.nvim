local M = {
	-- 1XX — Informational
	[100] = { text = "Continue" },
	[101] = { text = "Switching Protocols" },
	[102] = { text = "Processing" },
	[103] = { text = "Early Hints" },
	-- 2XX — Success
	[200] = { text = "OK", is_ok = true },
	[201] = { text = "Created", is_ok = true },
	[202] = { text = "Accepted", is_ok = true },
	[203] = { text = "Non-Authoritative Information", is_ok = true },
	[204] = { text = "No Content", is_ok = true },
	[205] = { text = "Reset Content", is_ok = true },
	[206] = { text = "Partial Content", is_ok = true },
	[207] = { text = "Multi-Status", is_ok = true },
	[208] = { text = "Already Reported", is_ok = true },
	[226] = { text = "IM Used", is_ok = true },
	-- 3XX — Redirection
	[300] = { text = "Multiple Choices" },
	[301] = { text = "Moved Permanently" },
	[302] = { text = "Found" },
	[303] = { text = "See Other" },
	[304] = { text = "Not Modified" },
	[307] = { text = "Temporary Redirect" },
	[308] = { text = "Permanent Redirect" },
	-- 4XX — Client Error
	[400] = { text = "Bad Request" },
	[401] = { text = "Unauthorized" },
	[402] = { text = "Payment Required" },
	[403] = { text = "Forbidden" },
	[404] = { text = "Not Found" },
	[405] = { text = "Method Not Allowed" },
	[406] = { text = "Not Acceptable" },
	[407] = { text = "Proxy Authentication Required" },
	[408] = { text = "Request Timeout" },
	[409] = { text = "Conflict" },
	[410] = { text = "Gone" },
	[411] = { text = "Length Required" },
	[412] = { text = "Precondition Failed" },
	[413] = { text = "Content Too Large" },
	[414] = { text = "URI Too Long" },
	[415] = { text = "Unsupported Media Type" },
	[416] = { text = "Range Not Satisfiable" },
	[417] = { text = "Expectation Failed" },
	[421] = { text = "Misdirected Request" },
	[422] = { text = "Unprocessable Content" },
	[423] = { text = "Locked" },
	[424] = { text = "Failed Dependency" },
	[425] = { text = "Too Early" },
	[426] = { text = "Upgrade Required" },
	[428] = { text = "Precondition Required" },
	[429] = { text = "Too Many Requests" },
	[431] = { text = "Request Header Fields Too Large" },
	[451] = { text = "Unavailable for Legal Reasons" },
	-- 5XX — Server Error
	[500] = { text = "Internal Server Error" },
	[501] = { text = "Not Implemented" },
	[502] = { text = "Bad Gateway" },
	[503] = { text = "Service Unavailable" },
	[504] = { text = "Gateway Timeout" },
	[505] = { text = "HTTP Version Not Supported" },
	[506] = { text = "Variant Also Negotiates" },
	[507] = { text = "Insufficient Storage" },
	[508] = { text = "Loop Deline" },
	[511] = { text = "Network Authentication Required" },
}

M.get_status_def = function(status_code)
	local status = M[status_code] or { text = "invalid status code" }
	status.code = status_code
	return status
end

return M
