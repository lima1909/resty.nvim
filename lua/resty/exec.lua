local M = {}

---  Create an async job for the jq commend.
---
---@param callback_output function a call back for the output
---@param json string the JSON string
---@param jq_filter? string a jq filter, default is '.'
---@return job table an async job ('plenary.job')
local create_jq_job = function(callback_output, json, jq_filter)
	local filter = jq_filter or "."

	return require("plenary.job"):new({
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

			callback_output(output)
		end,
	})
end

local function print_output_to_buf(bufnr)
	return function(output)
		vim.schedule(function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
		end)
	end
end

--- Execute jq with an given jq-filter.
---
---@param bufnr number the buffer number for the output from the result
---@param json string the JSON string
---@param jq_filter? string a jq filter, default is '.'
M.jq = function(bufnr, json, jq_filter)
	create_jq_job(print_output_to_buf(bufnr), json, jq_filter):start()
end

--- Only for test purpose
M.__jq = function(callback_output, json, jq_filter)
	return create_jq_job(callback_output, json, jq_filter)
end

return M
