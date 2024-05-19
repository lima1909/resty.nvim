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

local function get_buf_context(bufnr)
	-- read the complete buffer
	local context = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- convert the full input of the buffer into a (json) line
	local json = table.concat(context, "")
	return json
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
				table.insert(out, 1, "ERROR:")
				table.insert(out, 2, "")
			end

			vim.schedule(function()
				vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, out)
			end)
		end,
	})

	jq:start()
end

local function output(response)
	local bufnr = get_or_create_bufnr()

	local winnr = win_exist(bufnr)
	if not winnr then
		-- vim.api.nvim_win_close(winnr, true)
		vim.cmd("vsplit")
		vim.cmd(string.format("buffer %d", bufnr))
		vim.cmd("wincmd r")

		winnr = vim.api.nvim_get_current_win()
	end

	vim.api.nvim_set_current_win(winnr)
	-- Delete buffer content
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

	-- write the new output
	local body = vim.split(response.body, "\n")
	for i, r in ipairs(body) do
		vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { r })
	end

	--[[ vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
	vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, response.headers)

	vim.api.nvim_win_set_buf(0, bufnr)
	vim.api.nvim_win_set_cursor(0, { 1, 1 }) ]]
end

local bufnr = get_or_create_bufnr()

vim.keymap.set("n", "f", function()
	local json = get_buf_context(bufnr)
	exec_jq(bufnr, json)
end, {
	silent = true,
	buffer = bufnr,
	desc = "format the json output with jq",
})

vim.keymap.set("n", "ff", function()
	local jq_filter = vim.fn.input("Filter: ")
	if jq_filter == "" then
		return
	end

	local json = get_buf_context(bufnr)
	exec_jq(bufnr, json, jq_filter)
end, {
	silent = true,
	buffer = bufnr,
	desc = "format the json output with jq with a given query",
})

local function run(req)
	local curl = require("plenary.curl")
	local response = curl.request(req)
	output(response)
end

run({
	url = "https://jsonplaceholder.typicode.com/comments",
	method = "GET",
})
