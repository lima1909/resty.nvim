local curl = require("plenary.curl")
local pjob = require("plenary.job")

local M = {}

-- --------- JQ -------------------
M._create_jq_job = function(json, callback, jq_filter)
	local filter = jq_filter or "."
	return pjob:new({
		command = "jq",
		args = { filter },
		writer = json,
		on_exit = function(job, code)
			local output

			if code == 0 then
				output = job:result()
			else
				output = job:stderr_result()
				table.insert(output, 1, "ERROR in parsing json with jq:")
				table.insert(output, 2, "")
				table.insert(output, "")
				table.insert(output, "")
				table.insert(output, ">>> you can press key: 'r' to [r]eset the view")
			end

			vim.schedule(function()
				job.is_finished = true
				callback(output, code)
			end)
		end,
	})
end

---  Create an async job for the jq commend.
---
---@param json string the JSON string
---@param callback function callback function where to get the result
---@param jq_filter? string a jq filter, default is '.'
M.jq = function(json, callback, jq_filter)
	M._create_jq_job(json, callback, jq_filter):start()
end

---  Create an sync job for the jq commend.
---
---@param timeout number  the timeout value in ms
---@param json string the JSON string
---@param callback function callback function where to get the result
---@param jq_filter? string a jq filter, default is '.'
M.jq_wait = function(timeout, json, callback, jq_filter)
	local job = M._create_jq_job(json, callback, jq_filter)
	job:start()

	vim.wait(timeout, function()
		return job.is_finished
	end)

	job:shutdown()
end

-- --------- CURL -------------------
M._create_curl_job = function(request, callback, error)
	local job
	request.callback = function(result)
		job.is_finished = true

		if request.script then
			result.global_variables = M.script(request.script, result)
		else
			result.global_variables = {}
		end

		callback(result)
	end
	request.on_error = function(result)
		job.is_finished = true
		error(result)
	end

	-- return the created job
	-- Note: the job is already stated
	job = curl.request(request.url, request)
	return job
end

---  Create an async job for the curl commend.
---
---@param request table  the request definition
---@param callback function callback function where to get the result
---@param error function callback function to get the error result if it occurred
M.curl = function(request, callback, error)
	return M._create_curl_job(request, callback, error)
end

---  Create an sync job for the curl commend.
---
---@param timeout number  the timeout value in ms
---@param request table  the request definition
---@param callback function callback function where to get the result
---@param error function callback function to get the error result if it occurred
M.curl_wait = function(timeout, request, callback, error)
	local job = M._create_curl_job(request, callback, error)
	vim.wait(timeout, function()
		return job.is_finished
	end)

	job:shutdown()
end

M.exec_with_stop_time = function(fn, ...)
	local start_time = vim.loop.hrtime()
	local results = { fn(...) }
	table.insert(results, vim.loop.hrtime() - start_time)
	---@diagnostic disable-next-line: deprecated
	return unpack(results)
end

M.cmd = function(cmd)
	local handle = io.popen(cmd .. " 2>&1")
	if handle then
		-- read the cmd output
		local result = handle:read("*a")
		handle:close()
		return result
	end

	return "could not create a handle for command: " .. cmd
end

function M.script(code, result)
	if not code or vim.trim(code):len() == 0 then
		return {}
	end

	M.global_variables = {}

	local ctx = {
		-- body = '{}', status = 200, headers = {}, exit = 0, global_variables = {}
		result = result,
		-- set global variables with key and value
		set = function(key, value)
			M.global_variables[tostring(key)] = tostring(value)
		end,
		-- JSON parse the body
		json_body = function()
			return vim.json.decode(result.body)
		end,
		-- jq to the body
		jq_body = function(filter)
			local b = string.gsub(result.body, "\n", " ")
			local c = "echo '" .. b .. "' | jq '" .. filter .. "'"
			local r = M.cmd(c)
			return string.gsub(r, "\n", "")
		end,
	}

	local env = { ctx = ctx }
	setmetatable(env, { __index = _G })

	local f, err = load(code, "script error", "bt", env) -- 't' indicates that the env is a table
	if f then
		f()
	else
		error(err, 0)
	end

	return M.global_variables
end

return M
