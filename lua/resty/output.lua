local default_output = "response"

local function get_or_create_bufnr(name)
	local output = name or default_output
	local bufnr = nil

	for _, id in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(id):find(output) then
			return id
		end
	end

	if not bufnr then
		bufnr = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(bufnr, output)
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
		vim.api.nvim_set_option_value("filetype", "json", { buf = bufnr })
		vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
		vim.api.nvim_buf_set_option(bufnr, "buflisted", false)
	end

	return bufnr
end

local function win_exist(bufnr)
	for _, id in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(id) == bufnr then
			return id
		end
	end
end

local function exec_jq(bufnr, json, jq_filter)
	local filter = jq_filter or "."
	local job = require("plenary.job")

	local jq = job:new({
		command = "jq",
		args = { filter },
		writer = json,
		on_exit = function(j, code)
			local out
			if code == 0 then
				out = j:result()
			else
				out = j:stderr_result()
				table.insert(out, 1, json)
				table.insert(out, 2, "ERROR:")
			end

			vim.schedule(function()
				vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, out)
			end)
		end,
	})

	jq:start()
end

local function output()
	local bufnr = get_or_create_bufnr()

	local winnr = win_exist(bufnr)
	if winnr then
		-- vim.api.nvim_win_close(winnr, true)
		return
	end

	vim.cmd("vsplit")
	vim.cmd(string.format("buffer %d", bufnr))
	vim.cmd("wincmd r")
	-- vim.api.nvim_win_set_option(0, "spell", false)
	-- vim.api.nvim_win_set_option(0, "number", true)
	-- winnr = vim.api.nvim_get_current_win()
	-- vim.api.nvim_set_current_win(winnr)
	vim.api.nvim_buf_set_lines(
		bufnr,
		0,
		-1,
		false,
		{ '{"bufnr" : ' .. bufnr .. ', "person": { "name" : "' .. default_output .. '", "age": 42 }}' }
	)
end

local bufnr = get_or_create_bufnr()

vim.keymap.set("n", "f", function()
	-- read the complete buffer
	local buf_context = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	-- convert the full input of the buffer to on (json) line
	local json = table.concat(buf_context, "")
	-- Delete buffer content
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

	exec_jq(bufnr, json)
end, {
	silent = true,
	buffer = bufnr,
	desc = "format the json output with jq",
})

vim.keymap.set("n", "ff", function()
	-- read the complete buffer
	local buf_context = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	-- convert the full input of the buffer to on (json) line
	local json = table.concat(buf_context, "")

	local jq_filter = vim.fn.input("Filter: ")
	-- Delete buffer content
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

	exec_jq(bufnr, json, jq_filter)
end, {
	silent = true,
	buffer = bufnr,
	desc = "format the json output with jq with a given query",
})

output()
