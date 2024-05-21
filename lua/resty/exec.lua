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
					vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
				end)
			end,
		})
		:start()
end

return M
