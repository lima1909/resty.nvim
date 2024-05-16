local function buf_exist(name)
	for _, id in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(id):find(name) then
			return id
		end
	end

	return nil
end

local function win_exist(bufnr)
	for _, id in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(id) == bufnr then
			return id
		end
	end

	return nil
end

local name = "result"

local function output()
	local bufnr = buf_exist(name)

	if not bufnr then
		bufnr = vim.api.nvim_create_buf(false, false)

		vim.api.nvim_buf_set_name(bufnr, name)
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
		vim.api.nvim_set_option_value("filetype", "json", { buf = bufnr })
		vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
		vim.api.nvim_buf_set_option(bufnr, "buflisted", false)
	end

	vim.keymap.set("n", "R", function()
		print("R is pressed ...")
		vim.api.nvim_set_option_value("filetype", "http", { buf = bufnr })
	end, {
		silent = true,
		buffer = bufnr,
		desc = "a test for pressing an key",
	})

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

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '{"bufnr" : ' .. bufnr .. ', "name" : "' .. name .. '" }' })
end

output()
