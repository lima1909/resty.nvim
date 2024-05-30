local curl = require("plenary.curl")

local M = {}

---  Create an async job for the jq commend.
---
---@param bufnr number the buffer number for the output from the result
---@param json string the JSON string
---@param jq_filter? string a jq filter, default is '.'
M.jq = function(bufnr, json, jq_filter)
	local filter = jq_filter or "."

	require("plenary.job")
		:new({
			command = "jq",
			args = { filter },
			writer = json,
			on_exit = function(job, code)
				local output
				if code == 0 then
					output = job:result()
				else
					output = job:stderr_result()
					table.insert(output, 1, "ERROR:")
					table.insert(output, 2, "")
				end

				-- write the output (result or error) in buffer
				vim.schedule(function()
					vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, output)
				end)
			end,
		})
		:start()
end

M.http_status_codes = {
	-- 1XX — Informational
	[100] = "Continue",
	[101] = "Switching Protocols",
	[102] = "Processing",
	[103] = "Early Hints",
	-- 2XX — Success
	[200] = "OK",
	[201] = "Created",
	[202] = "Accepted",
	[203] = "Non-Authoritative Information",
	[204] = "No Content",
	[205] = "Reset Content",
	[206] = "Partial Content",
	[207] = "Multi-Status",
	[208] = "Already Reported",
	[226] = "IM Used",
	-- 3XX — Redirection
	[300] = "Multiple Choices",
	[301] = "Moved Permanently",
	[302] = "Found",
	[303] = "See Other",
	[304] = "Not Modified",
	[307] = "Temporary Redirect",
	[308] = "Permanent Redirect",
	-- 4XX — Client Error
	[400] = "Bad Request",
	[401] = "Unauthorized",
	[402] = "Payment Required",
	[403] = "Forbidden",
	[404] = "Not Found",
	[405] = "Method Not Allowed",
	[406] = "Not Acceptable",
	[407] = "Proxy Authentication Required",
	[408] = "Request Timeout",
	[409] = "Conflict",
	[410] = "Gone",
	[411] = "Length Required",
	[412] = "Precondition Failed",
	[413] = "Content Too Large",
	[414] = "URI Too Long",
	[415] = "Unsupported Media Type",
	[416] = "Range Not Satisfiable",
	[417] = "Expectation Failed",
	[421] = "Misdirected Request",
	[422] = "Unprocessable Content",
	[423] = "Locked",
	[424] = "Failed Dependency",
	[425] = "Too Early",
	[426] = "Upgrade Required",
	[428] = "Precondition Required",
	[429] = "Too Many Requests",
	[431] = "Request Header Fields Too Large",
	[451] = "Unavailable for Legal Reasons",
	-- 5XX — Server Error
	[500] = "Internal Server Error",
	[501] = "Not Implemented",
	[502] = "Bad Gateway",
	[503] = "Service Unavailable",
	[504] = "Gateway Timeout",
	[505] = "HTTP Version Not Supported",
	[506] = "Variant Also Negotiates",
	[507] = "Insufficient Storage",
	[508] = "Loop Detected",
	[511] = "Network Authentication Required",
}

M.curl = function(req_def)
	local response, duration = M.stop_time(function()
		return curl.request(req_def.req)
	end)

	response.status_str = vim.tbl_get(M.http_status_codes, response.status) or ""
	response.duration = duration
	response.duration_str = M.time_formated(duration)

	return response
end

M.stop_time = function(exec_fn)
	local start_time = os.clock()
	local result = exec_fn()
	local duration = os.clock() - start_time

	return result, duration
end

M.time_formated = function(time)
	local units = { "s", "ms", "µs", "ns" }
	local current_unit_pos = 1

	while time < 1 and current_unit_pos <= #units do
		time = time * 1000
		current_unit_pos = current_unit_pos + 1
	end

	return string.format("%.2f %s", time, units[current_unit_pos])
end

return M
