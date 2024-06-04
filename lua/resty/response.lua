local exec = require("resty.exec")

local M = {
	windows = {
		{
			id = 1,
			keymap = "b",
			name = "body",
			active = false,
			show = function(slf)
				vim.api.nvim_set_option_value("filetype", "json", { buf = slf.bufnr })
				local body = vim.split(slf.body_filtered, "\n")
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, body)
			end,
		},
		{
			id = 2,
			keymap = "h",
			name = "headers",
			active = false,
			show = function(slf)
				vim.api.nvim_set_option_value("filetype", "http", { buf = slf.bufnr })
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, slf.response.headers)
			end,
		},
		{
			id = 3,
			keymap = "i",
			name = "info",
			active = false,
			show = function(slf)
				vim.api.nvim_set_option_value("filetype", "markdown", { buf = slf.bufnr })
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, {
					"Request:",
					"",
					"```http",
					"",
					slf.req_def.req.method .. " " .. slf.req_def.req.url,
					"",
					-- "# headers",
					-- "" .. vim.fn.flatten(slf.req_def.headers),
					"```",
					"",
					"",
					"Response: ",
					"",
					"- state: " .. slf.response.status .. " " .. slf.response.status_str,
					"- duration: " .. slf.response.duration_str,
				})
			end,
		},
	},
}

local key_mappings = {
	f = {
		win_ids = { 1 },
		rhs = function()
			exec.jq(M.body_filtered, function(json)
				local new_body = table.concat(json, "\n")
				M.body_filtered = new_body
				M:show(1)
			end)
		end,
		desc = "format the json output with jq",
	},
	ff = {
		win_ids = { 1 },
		rhs = function()
			local jq_filter = vim.fn.input("Filter: ")
			if jq_filter == "" then
				return
			end
			exec.jq(M.body_filtered, function(json)
				local new_body = table.concat(json, "\n")
				M.body_filtered = new_body
				M:show(1)
			end, jq_filter)
		end,
		desc = "format the json output with jq with a given query",
	},
	r = {
		win_ids = { 1 },
		rhs = function()
			M.body_filtered = M.response.body
			M:show(1)
		end,
		desc = "reset the current filtered body",
	},
}

function M:activate_key_mapping_for_win(win_id)
	for key, def in pairs(key_mappings) do
		if vim.tbl_get(def.win_ids, win_id) then
			vim.keymap.set("n", key, def.rhs, { buffer = self.bufnr, silent = true, desc = def.desc })
		else
			vim.keymap.set("n", key, function() end, { buffer = self.bufnr, silent = true, desc = "NOT SET" })
		end
	end
end

local function get_or_create_buffer_with_win()
	local bufname = "result"
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
		vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
		vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
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

local function create_hl()
	-- vim.api.nvim_create_namespace("Resty"),
	vim.api.nvim_set_hl(0, "ActiveWin", { underdouble = true, bold = true, force = true })
	vim.api.nvim_set_hl(0, "StatusOK", { fg = "grey" })
	vim.api.nvim_set_hl(0, "StatusNotOK", { fg = "red" })
end

local function windows_bar_str(win)
	local win_name = win.name
	if win.active == true then
		win_name = "%#ActiveWin#" .. win_name .. "%*"
	end

	return "%" .. win.id .. "@v:lua._G._resty_show_response@" .. win_name .. "%X"
end

function M:create_winbar(selection)
	local winbar = "| "
	for _, win in pairs(self.windows) do
		if win.id == selection then
			win.active = true
		else
			win.active = false
		end

		winbar = winbar .. windows_bar_str(win) .. " | "
	end

	--check the status-code is an 200er
	local status_hl = "%#StatusOK#"
	local first = string.sub("" .. self.response.status, 1, 1)
	if first ~= "2" then
		status_hl = "%#StatusNotOK#"
	end

	-- add the status with duration to the winbar
	winbar = winbar
		.. "  "
		.. status_hl
		.. self.response.status
		.. " "
		.. self.response.status_str
		.. "  ("
		.. self.response.duration_str
		.. ")%*"

	return winbar
end

function M:show(selection)
	local sel = selection or 1

	vim.wo[self.winnr].winbar = self:create_winbar(sel)

	-- Delete buffer content and write an empty line
	vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, { "" })
	vim.api.nvim_win_set_buf(0, self.bufnr)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	for _, win in pairs(self.windows) do
		if win.id == sel then
			win.show(self)
		end

		-- create keymaps for the given window
		vim.keymap.set("n", win.keymap, function()
			self:show(win.id)
		end, { buffer = self.bufnr, silent = true })
	end

	-- create keymaps only for the active window
	self:activate_key_mapping_for_win(sel)
end

M.new = function(req_def, response)
	M.req_def = req_def
	M.response = response
	M.body_filtered = response.body
	M.bufnr, M.winnr = get_or_create_buffer_with_win()

	-- create highlighting for the winbar
	create_hl()

	return M
end

return M
