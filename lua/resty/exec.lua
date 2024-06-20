local curl = require("plenary.curl")

local M = {}

---  Create an async job for the jq commend.
---
---@param json string the JSON string
---@param callback function callback function where to get the result
---@param jq_filter? string a jq filter, default is '.'
M.jq = function(json, callback, jq_filter)
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
					table.insert(output, "")
					table.insert(output, "")
					table.insert(output, ">>> press key: 'r' to get the original json string")
				end

				vim.schedule(function()
					callback(output)
				end)
			end,
		})
		:start()
end

---  Create an async job for the curl commend.
---
---@param req_def table  the request definition
---@param callback function callback function where to get the result
---@param error function callback function to get the error result if it occured
M.curl = function(req_def, callback, error)
	req_def.req.callback = callback
	req_def.req.on_error = error

	curl.request(req_def.req.url, req_def.req)
end

return M
