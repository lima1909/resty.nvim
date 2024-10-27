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
		-- return M.bufnr, M.winnr
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

	-- Delete buffer content
	vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, {})
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
	self.bufnr, self.winnr = M._create_buf_with_win(self.bufname)

	self.call_from_buffer_name = vim.fn.bufname("%")
	self.parse_result = parse_result
	self.parse_result.duration_str = format.duration(self.parse_result.duration)
	self.curl.canceled = false

	local start_time = os.clock()

	self.curl.job = exec.curl(parse_result.request, function(response)
		parser.set_global_variables(response.global_variables)
		self:stop_time(os.clock() - start_time)
		vim.schedule(function()
			self:show_response(response)
		end)
	end, function(error)
		self:stop_time(os.clock() - start_time)
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
	-- is a dry run
	else
		self:stop_time(os.clock() - start_time)
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

function M:stop_time(duration)
	self.curl.duration = duration
	self.curl.duration_str = format.duration(self.curl.duration)
end

function M:create_and_select_window(menu_ids, status)
	local menus = {}

	for _, id in ipairs(menu_ids) do
		-- convert window to winbar menu
		local m = windows.menu[id]
		table.insert(menus, m)

		-- create keymaps for the given window
		vim.keymap.set("n", m.keymap, function()
			self:select_window(m.id)
		end, { buffer = self.bufnr, silent = true })
	end

	-- create a new winbar
	self.winbar = winbar.new(self.winnr, menus, status, self.curl.duration_str)

	local menu_id = menu_ids[self.current_menu_id]
	if not menu_id then
		-- if not found, then select the first menu in the list
		menu_id = menu_ids[1]
	end
	self:select_window(menu_id)
end

function M:select_window(selected_id)
	self.current_menu_id = selected_id
	if not windows.menu[self.current_menu_id] then
		-- if selected_id out of range, set to window id = 1
		self.current_menu_id = 1
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
