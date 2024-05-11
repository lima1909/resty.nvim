local curl = require("plenary.curl")
local parser = require("resty.parser")

local M = {}

_Last_req_def = nil

local print_response_to_new_buf = function(req_def, response)
	local buf = vim.api.nvim_create_buf(true, true)
	-- vim.api.nvim_buf_set_name(buf, "Resty.http")
	vim.api.nvim_set_option_value("filetype", "http", { buf = buf })

	vim.api.nvim_buf_set_lines(
		buf,
		0,
		-1,
		false,
		{ "Request: " .. req_def.name .. " [" .. req_def.start_at .. " - " .. req_def.end_at .. "]" }
	)
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "Response state: " .. response.status, "" })
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, response.headers)
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })

	local body = vim.split(response.body, "\n")
	-- local line_nr = vim.api.nvim_buf_line_count(buf)
	for i, r in ipairs(body) do
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, { r })
	end

	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
end

M.last = function()
	if _Last_req_def then
		local response = curl.request(_Last_req_def.req)
		print_response_to_new_buf(_Last_req_def, response)
	else
		error("No last request found. Run first [Resty run]")
	end
end

M.run = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), true)
	local definitions = parser.parse(lines)

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local found_def

	for name, d in pairs(definitions) do
		if d.start_at <= row and d.end_at >= row then
			found_def = name
			break
		end
	end

	local def = definitions[found_def]
	assert(def, "The cursor pointed not to a valid request definition")

	local response = curl.request(def.req)
	_Last_req_def = def

	print_response_to_new_buf(def, response)
end

return M
