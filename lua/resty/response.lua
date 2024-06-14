local exec = require("resty.exec")

local M = {
	windows = {
		{
			id = 1,
			keymap = "b",
			name = "body",
			active = false,
			show_window = function(slf)
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
			show_window = function(slf)
				vim.api.nvim_set_option_value("filetype", "http", { buf = slf.bufnr })
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, slf.response.headers)
			end,
		},
		{
			id = 3,
			keymap = "i",
			name = "info",
			active = false,
			show_window = function(slf)
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
					"- state: " .. slf.response.status .. " " .. slf.response.status_str,
					"- duration: " .. slf.meta.duration_str,
					"",
					"Meta",
					"- call from buffer: '" .. slf.meta.buffer_name .. "'",
				})
			end,
		},
	},
}

M.set_folding = function()
	if M.config.with_folding then
		vim.cmd("setlocal foldmethod=expr")
		vim.cmd("setlocal foldexpr=v:lua.vim.treesitter.foldexpr()")
		vim.cmd("setlocal foldlevel=2")
	else
		vim.cmd("setlocal foldmethod=manual")
		vim.cmd("normal zE")
	end
end

local key_mappings = {
	-- p: pretty print
	p = {
		win_ids = { 1 },
		rhs = function()
			exec.jq(M.body_filtered, function(json)
				local new_body = table.concat(json, "\n")
				M.body_filtered = new_body
				M:seltect_window(1)
			end)
		end,
		desc = "pretty print with jq",
	},
	-- q: jq query
	q = {
		win_ids = { 1 },
		rhs = function()
			local jq_filter = vim.fn.input("Filter: ")
			if jq_filter == "" then
				return
			end
			exec.jq(M.body_filtered, function(json)
				local new_body = table.concat(json, "\n")
				M.body_filtered = new_body
				M:seltect_window(1)
			end, jq_filter)
		end,
		desc = "querying with jq",
	},
	r = {
		win_ids = { 1 },
		rhs = function()
			M.body_filtered = M.response.body
			M:seltect_window(1)
		end,
		desc = "reset to the original responsne body",
	},
	zz = {

		win_ids = { 1 },
		rhs = function()
			M.config.with_folding = not M.config.with_folding
			M.set_folding()
		end,
		desc = "toggle folding, if activated",
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

local function create_buffer_with_win(bnr)
	local bufname = "result"

	if bnr then
		vim.api.nvim_buf_delete(bnr, { force = true })
	end

	-- buffer
	local bufnr = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_name(bufnr, bufname)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
	vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
	vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })

	-- window
	vim.cmd("vsplit")
	vim.cmd(string.format("buffer %d", bufnr))
	vim.cmd("wincmd r")

	local winnr = vim.api.nvim_get_current_win()
	vim.api.nvim_set_current_win(winnr)

	-- Delete buffer content
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

	return bufnr, winnr
end

local function windows_bar_str(win)
	local win_name = win.name

	if win.active == true then
		win_name = "%#ActiveWin#" .. win_name .. "%*"
	end

	return "%" .. win.id .. "@v:lua._G._resty_show_response@" .. win_name .. "%X"
end

function M:create_winbar(selection)
	-- vim.api.nvim_create_namespace("Resty"),
	vim.api.nvim_set_hl(0, "ActiveWin", { underdouble = true, bold = true, force = true })
	vim.api.nvim_set_hl(0, "StatusOK", { fg = "grey" })
	vim.api.nvim_set_hl(0, "StatusNotOK", { fg = "red" })

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
		.. self.meta.duration_str
		.. ")%*"
	return winbar
end

function M:seltect_window(selection)
	local sel = selection or 1

	vim.wo[self.winnr].winbar = self:create_winbar(sel)
	-- Delete buffer content and write an empty line
	vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, { "" })
	vim.api.nvim_win_set_buf(0, self.bufnr)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	for _, win in pairs(self.windows) do
		if win.id == sel then
			win.show_window(self)
		end
		-- create keymaps for the given window
		vim.keymap.set("n", win.keymap, function()
			self:seltect_window(win.id)
		end, { buffer = self.bufnr, silent = true })
	end

	-- create keymaps only for the active window
	self:activate_key_mapping_for_win(sel)
end

function M:show(req_def, response, meta)
	M.req_def = req_def
	M.response = response
	M.body_filtered = response.body
	M.response.status_str = vim.tbl_get(exec.http_status_codes, response.status) or ""
	M.meta = meta
	M.meta.duration_str = exec.time_formated(meta.duration)

	self:seltect_window()
end

function M:show_error(error)
	local err_msg = error.message
	local method_url_pos = err_msg:find("-")

	local new_err_msg = ""
	if method_url_pos then
		new_err_msg = new_err_msg .. vim.trim(string.sub(err_msg, 1, method_url_pos - 1))
	end

	vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, {
		"ERROR:",
		"",
		new_err_msg,
		"",
		"" .. error.stderr:sub(4, -4),
	})
end

function M.new(config)
	M.config = config
	M.bufnr, M.winnr = create_buffer_with_win(M.bufnr)
	-- set global config values
	M.set_folding()

	return M
end

return M
