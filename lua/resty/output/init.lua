local winbar = require("resty.output.winbar")
local windows = require("resty.output.windows")
local format = require("resty.output.format")
local statuscode = require("resty.output.statuscode")
local exec = require("resty.exec")
local parser = require("resty.parser")

local M = { bufnr = nil, winnr = nil }

local default_bufname = "resty_response"

function M._create_buf_with_win(bufname)
	-- clear buffer, if exist
	if M.bufnr and vim.api.nvim_buf_is_valid(M.bufnr) and vim.api.nvim_buf_is_loaded(M.bufnr) then
		vim.api.nvim_buf_delete(M.bufnr, { force = true })
	end

	-- create a new buffer
	M.bufnr = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_name(M.bufnr, bufname)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = M.bufnr })
	vim.api.nvim_set_option_value("swapfile", false, { buf = M.bufnr })
	vim.api.nvim_set_option_value("buflisted", false, { buf = M.bufnr })

	-- create a new window
	vim.api.nvim_open_win(M.bufnr, true, { split = "right" })
	M.winnr = vim.api.nvim_get_current_win()

	-- activate the window
	vim.api.nvim_set_current_win(M.winnr)
	vim.api.nvim_buf_set_lines(M.bufnr, -1, -1, false, { "please wait ..." })

	return M.bufnr, M.winnr
end

function M.new(config)
	local cfg = vim.tbl_deep_extend("force", { output = { body_pretty_print = false } }, config or {})

	local out = setmetatable({
		cfg = cfg,
		bufname = cfg.bufname or default_bufname,
		current_menu_id = 0,
		curl = { duration = 0, job = nil },
	}, { __index = M })

	return out
end

function M:exec_and_show_response(parse_result)
	self.call_from_buffer_name = vim.fn.bufname("%")

	self.parse_result = parse_result
	self.parse_result.duration_str = format.duration_to_str(self.parse_result.duration)
	self.curl.canceled = false
	self.bufnr, self.winnr = M._create_buf_with_win(self.bufname)
	local start_time = vim.loop.hrtime()

	self.curl.job = exec.curl(parse_result.request, function(response)
		self:stop_time(start_time)
		parser.set_global_variables(response.global_variables)

		vim.schedule(function()
			self:show_response(response)
		end)
	end, function(error)
		self:stop_time(start_time)

		vim.schedule(function()
			-- if curl canceled, dont print an error
			if self.curl.canceled == false then
				self:show_error(error)
			end
		end)
	end)

	-- is really a job, not a dry run
	if getmetatable(self.curl.job) then
		-- activate curl cancel
		vim.keymap.set("n", "cc", function()
			if self.curl.job and not self.curl.job.is_shutdown then
				self.curl.canceled = true
				self.curl.job:shutdown()

				-- Delete buffer content
				vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
				vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, { "curl is canceled ..." })
			end
		end, { buffer = self.bufnr, silent = true, desc = "cancel curl request" })

		-- show timeout, if timeout is set
		self:show_timeout(self.parse_result.request.timeout)
	-- is a dry run
	else
		self:stop_time(start_time)
		self:show_dry_run(self.curl.job)
	end
end

function M:show_response(response)
	self.response = response
	self.current_body = response.body

	--  1 - body, 2 - header, 2 - info, 4 - help
	self:create_and_select_window({ 1, 2, 3, 4 }, statuscode.get_status_def(response.status))
end

function M:show_error(error)
	self.curl.error = error

	-- 5 - error, 3 - info
	self:create_and_select_window({ 5, 3 }, { code = "", text = "curl error", is_ok = false })
end

function M:show_dry_run(job)
	self.curl.job = {}
	self.curl.job.args = job

	-- 6 - job, 3 - info
	self:create_and_select_window({ 6, 3 }, { code = "", text = "curl dry run", is_ok = true })
end

function M:show_timeout(timeout)
	if timeout then
		vim.cmd("redraw")

		vim.wait(timeout, function()
			return self.curl.job.is_finished
		end)

		if self.curl.job.is_finished == false then
			self.curl.canceled = true
			self.curl.job:shutdown()

			self.curl.timeout = timeout
			-- 7 - timeout, 3 - info
			self:create_and_select_window({ 7, 3 }, { code = "", text = "curl timeout", is_ok = true })
		end
	end
end

function M:stop_time(start_time)
	self.curl.duration = vim.loop.hrtime() - start_time
	self.curl.duration_str = format.duration_to_str(self.curl.duration)
end

function M:create_and_select_window(menu_ids, status)
	self.menus = {}

	for _, id in ipairs(menu_ids) do
		-- convert window to winbar menu
		local m = windows.menu[id]
		table.insert(self.menus, m)

		-- create keymaps for the given window
		vim.keymap.set("n", m.keymap, function()
			self:select_window(m.id)
		end, { buffer = self.bufnr, silent = true })
	end

	-- create a new winbar
	self.winbar = winbar.new(self.winnr, self.menus, status, self.curl.duration_str)

	local menu_id = self.current_menu_id
	if menu_id == 0 then
		--if no id set, then start with first id
		menu_id = self.menus[1].id
	end
	self:select_window(menu_id)
end

function M:select_window(selected_id)
	self.current_menu_id = self.menus[1].id
	for _, m in ipairs(self.menus) do
		if selected_id == m.id then
			self.current_menu_id = selected_id
			break
		end
	end

	self.winbar:select(self.current_menu_id)

	-- Delete buffer content and write an empty line
	vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, { "" })

	vim.api.nvim_win_set_buf(self.winnr, self.bufnr)
	vim.api.nvim_win_set_cursor(self.winnr, { 1, 0 })

	-- show current window content
	windows.menu[self.current_menu_id].show_window_content(self)
	-- create keymaps only for the active window
	self:activate_key_mapping_for_win()
end

function M:activate_key_mapping_for_win()
	for key, def in pairs(windows.key_mappings) do
		if def.win_ids[self.current_menu_id] then
			vim.keymap.set("n", key, function()
				def.rhs(self)
			end, { buffer = self.bufnr, silent = true, desc = def.desc })
		else
			vim.keymap.set("n", key, function() end, { buffer = self.bufnr, silent = true, desc = "NOT SET" })
		end
	end
end

return M
