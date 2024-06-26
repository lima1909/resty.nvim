local winbar = require("resty.output.winbar")
local format = require("resty.output.format")
local statuscode = require("resty.output.statuscode")
local exec = require("resty.exec")

local M = {
	windows = {
		[1] = {
			keymap = "b",
			name = "body",
			show_window_content = function(slf)
				vim.api.nvim_set_option_value("filetype", "json", { buf = slf.bufnr })
				local body = vim.split(slf.current_body, "\n")
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, body)
			end,
		},
		[2] = {
			keymap = "h",
			name = "headers",
			show_window_content = function(slf)
				vim.api.nvim_set_option_value("filetype", "http", { buf = slf.bufnr })
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, slf.response.headers)
			end,
		},
		[3] = {
			keymap = "i",
			name = "info",
			show_window_content = function(slf)
				vim.api.nvim_set_option_value("filetype", "markdown", { buf = slf.bufnr })
				-- "# headers",
				-- "" .. vim.fn.flatten(slf.req_def.headers),

				local req = slf.req_def.req
				-- REQUEST
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, {
					"Request:",
					"",
					"```http",
					"",
					req.method .. " " .. req.url,
					"",
				})

				-- BODY
				if req.body then
					exec.jq_wait(2000, req.body, function(json)
						vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, json)
					end)
				end

				-- RESPONSE AND META
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, {
					"```",
					"",
					"Response: ",
					"- state: " .. slf.meta.status_str,
					"- duration: " .. slf.meta.duration_str,
					"",
					"Meta",
					"- call from buffer: '" .. slf.meta.buffer_name .. "'",
				})
			end,
		},
	},
}

local window_key_mappings = {
	-- p: pretty print
	["p"] = {
		win_ids = { 1 },
		rhs = function()
			exec.jq(M.current_body, function(json)
				local new_body = table.concat(json, "\n")
				M.current_body = new_body
				M:select_window(1)
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
			exec.jq(M.current_body, function(json)
				local new_body = table.concat(json, "\n")
				M.current_body = new_body
				M:select_window(1)
			end, jq_filter)
		end,
		desc = "querying with jq",
	},
	r = {
		win_ids = { 1 },
		rhs = function()
			M.current_body = M.response.body
			M:select_window(1)
		end,
		desc = "reset to the original responsne body",
	},
	zz = {

		win_ids = { 1, nil, 3 },
		rhs = function()
			M.cfg.with_folding = not M.cfg.with_folding
			M.set_folding(M.cfg.with_folding)
		end,
		desc = "toggle folding, if activated",
	},
}

function M.new(config)
	M.cfg = config or {}
	M.meta = {}
	M.bufname = M.cfg.bufname or "resty_response"
	M.current_window_id = 0

	-- reset buffer
	if M.bufnr and vim.api.nvim_buf_is_valid(M.bufnr) and vim.api.nvim_buf_is_loaded(M.bufnr) then
		vim.api.nvim_buf_delete(M.bufnr, { force = true })
	end
	M.bufnr = nil

	return M
end

function M:activate_key_mapping_for_win(winid)
	for key, def in pairs(window_key_mappings) do
		if def.win_ids[winid] then
			vim.keymap.set("n", key, def.rhs, { buffer = self.bufnr, silent = true, desc = def.desc })
		else
			vim.keymap.set("n", key, function() end, { buffer = self.bufnr, silent = true, desc = "NOT SET" })
		end
	end
end

local function create_buf_with_win(bufnr, bufname)
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end

	-- create a new buffer
	bufnr = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_name(bufnr, bufname)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
	vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
	vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })

	-- create a new window
	vim.api.nvim_open_win(bufnr, true, { split = "right" })
	local winnr = vim.api.nvim_get_current_win()
	return bufnr, winnr
end

function M.set_folding(with_folding)
	if with_folding then
		-- if M.config.with_folding then
		vim.cmd("setlocal foldmethod=expr")
		vim.cmd("setlocal foldexpr=v:lua.vim.treesitter.foldexpr()")
		vim.cmd("setlocal foldlevel=2")
	else
		vim.cmd("setlocal foldmethod=manual")
		vim.cmd("normal zE")
	end
end

function M:select_window(selected_id)
	self.current_window_id = selected_id
	if not self.windows[self.current_window_id] then
		-- if selected_id out of range, set to window id = 1
		self.current_window_id = 1
	end

	self.winbar:select(self.current_window_id, self.meta.statusdef, self.meta.duration_str)

	-- Delete buffer content and write an empty line
	vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, { "" })

	vim.api.nvim_win_set_buf(self.winnr, self.bufnr)
	vim.api.nvim_win_set_cursor(self.winnr, { 1, 0 })

	-- show current window content
	self.windows[self.current_window_id].show_window_content(self)
	-- create keymaps only for the active window
	self:activate_key_mapping_for_win(self.current_window_id)
end

function M:activate()
	self.bufnr, self.winnr = create_buf_with_win(self.bufnr, self.bufname)
	-- activate curl cancel
	vim.keymap.set("n", "cc", function()
		if M.curl then
			M.curl:shutdown()
			M.curl = nil

			-- Delete buffer content
			vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, {})
			vim.api.nvim_buf_set_lines(M.bufnr, -1, -1, false, { "curl is canceled ..." })
		end
	end, { buffer = M.bufnr, silent = true, desc = "cancel curl request" })
	-- set winbar
	self.winbar = winbar.new(self)

	self.set_folding(self.cfg.with_folding)

	-- activate the window
	vim.api.nvim_set_current_win(self.winnr)
	-- Delete buffer content
	vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
	vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, { "please wait ..." })

	return self
end

function M:show(req_def, response)
	self.req_def = req_def
	self.response = response
	self.current_body = response.body

	self.meta.statusdef = statuscode.get_status_def(self.response.status)
	self.meta.status_str = self.meta.statusdef.code .. " " .. self.meta.statusdef.text
	self.meta.duration_str = format.duration(self.meta.duration)

	self:select_window(self.current_window_id)
end

function M:show_error(error)
	local err_msg = error.message
	local method_url_pos = err_msg:find("-")

	local new_err_msg = ""
	if method_url_pos then
		new_err_msg = new_err_msg .. vim.trim(string.sub(err_msg, 1, method_url_pos - 1))
	end

	vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {
		"ERROR:",
		"",
		new_err_msg,
		"",
		"" .. error.stderr:sub(4, -4),
	})
end

function M:exec_and_show_response(parser_result)
	self.meta = { buffer_name = vim.fn.bufname("%") }
	self:activate()

	-- start the stop time
	local start_time = os.clock()

	self.curl = exec.curl(parser_result.result, function(result)
		self.meta.duration = os.clock() - start_time

		vim.schedule(function()
			self:show(parser_result.result, result)
		end)
	end, function(error)
		vim.schedule(function()
			-- if curl canceled, dont print an error
			if M.curl then
				self:show_error(error)
			end
		end)
	end)
end

return M
