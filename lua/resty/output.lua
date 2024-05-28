local exec = require("resty.exec")

local M = {}

local show_body_flag = true
local show_headers_flag = true
local show_meta_flag = true

local function get_or_create_buffer_with_win()
	local bufname = "response"
	local bufnr = nil

	for _, id in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(id):find(bufname) then
			bufnr = id
		end
	end

	if not bufnr then
		bufnr = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(bufnr, bufname)
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
		vim.api.nvim_set_option_value("filetype", "json", { buf = bufnr })
		vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
		vim.api.nvim_buf_set_option(bufnr, "buflisted", false)
	end

	-- window
	local winnr
	for _, id in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(id) == bufnr then
			winnr = id
		end
	end

	if not winnr then
		vim.cmd("vsplit")
		vim.cmd(string.format("buffer %d", bufnr))
		vim.cmd("wincmd r")
		winnr = vim.api.nvim_get_current_win()
	end

	vim.api.nvim_set_current_win(winnr)
	-- Delete buffer content
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

	return bufnr, winnr
end

--[[ local function get_buf_context(bufnr)
	-- read the complete buffer
	local context = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	-- convert the full input of the buffer into a (json) line
	local json = table.concat(context, "")
	return json
end ]]

function M:show_meta()
	if show_meta_flag then
		vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {
			"Request: "
				.. self.req_def.name
				.. " ["
				.. self.req_def.start_at
				.. " - "
				.. self.req_def.end_at
				.. "] duration: "
				.. self.duration
				.. " ms >> response Status: "
				.. self.response.status
				.. " "
				.. self.response.status_str,
			"",
		})
	end
end

function M:show_body()
	if show_body_flag then
		local b = vim.split(self.response.body, "\n")
		for _, r in ipairs(b) do
			vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, { r })
		end
	end
end

function M:show_headers()
	if show_headers_flag then
		vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, self.response.headers)
	end
end

function M:show()
	-- set high light
	vim.api.nvim_set_hl(
		vim.api.nvim_create_namespace("Resty"),
		"Active",
		{ underline = true, bold = true, italic = true }
	)
	-- set winbar with two menus
	vim.wo[self.winnr].winbar = "%1@v:lua.print@|%#Active# print 1 %*|%X%7@v:lua.print@ print 2 |%X"

	self:show_meta()
	self:show_body()

	vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, { "" })
	self:show_headers()

	vim.api.nvim_win_set_buf(0, M.bufnr)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

function M:refresh()
	-- Delete buffer content
	vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, {})
	M:show()
end

-- add key-mapping for using jq for the json-body
-- ----------------------------------------------
local key_mappings = {
	m = {
		rhs = function()
			show_meta_flag = not show_meta_flag
			M:refresh()
		end,
		desc = "toggle for meta",
	},
	b = {
		rhs = function()
			show_body_flag = not show_body_flag
			M:refresh()
		end,
		desc = "toggle for body",
	},
	h = {
		rhs = function()
			show_headers_flag = not show_headers_flag
			M:refresh()
		end,
		desc = "toggle for headers",
	},
	f = {
		rhs = function()
			if show_body_flag then
				--get_buf_context(bufnr)
				exec.jq(M.bufnr, M.body_filtered)
			end
		end,
		desc = "format the json output with jq",
	},
	ff = {
		rhs = function()
			if show_body_flag then
				local jq_filter = vim.fn.input("Filter: ")
				if jq_filter == "" then
					return
				end

				--get_buf_context(bufnr)
				exec.jq(M.bufnr, M.body_filtered, jq_filter)
			end
		end,
		desc = "format the json output with jq with a given query",
	},
	fr = {
		rhs = function()
			if show_body_flag then
				M.body_filtered = M.response.body
				M:refresh()
			end
		end,
		desc = "reset the current filtered body",
	},
}

local function setup_keymap()
	for key, def in pairs(key_mappings) do
		vim.keymap.set("n", key, def.rhs, { buffer = M.bufnr, desc = def.desc, silent = true })
	end
end

M.new = function(req_def, response)
	M.req_def = req_def
	M.response = response
	M.body_filtered = response.body
	M.duration = response.duration
	M.bufnr, M.winnr = get_or_create_buffer_with_win()

	setup_keymap()

	return M
end

return M
