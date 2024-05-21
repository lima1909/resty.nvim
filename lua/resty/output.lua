local exec = require("resty.exec")

local M = {}

local function get_or_create_bufnr(name)
	local output = name or "response"
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

local function show_win(bufnr)
	local winnr = win_exist(bufnr)
	if not winnr then
		vim.cmd("vsplit")
		vim.cmd(string.format("buffer %d", bufnr))
		vim.cmd("wincmd r")

		winnr = vim.api.nvim_get_current_win()
	end

	vim.api.nvim_set_current_win(winnr)
	-- Delete buffer content
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
end

M.show_response = function(req_def, response, duration)
	local bufnr = get_or_create_bufnr()
	show_win(bufnr)

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"Request: "
			.. req_def.name
			.. " ["
			.. req_def.start_at
			.. " - "
			.. req_def.end_at
			.. "] duration: "
			.. duration
			.. " ms >> response Status: "
			.. response.status,
		"",
	})

	local body = vim.split(response.body, "\n")
	for _, r in ipairs(body) do
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { r })
	end

	vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
	vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, response.headers)

	vim.api.nvim_win_set_buf(0, bufnr)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	-- add key-mapping for using jq for the json-body
	-- ----------------------------------------------
	vim.keymap.set("n", "f", function()
		local json = response.body --get_buf_context(bufnr)
		exec.jq(bufnr, json)
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

		local json = response.body --get_buf_context(bufnr)
		exec.jq(bufnr, json, jq_filter)
	end, {
		silent = true,
		buffer = bufnr,
		desc = "format the json output with jq with a given query",
	})
end

return M
