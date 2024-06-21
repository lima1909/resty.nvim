local output = require("resty.output")
local assert = require("luassert")

describe("output:", function()
	it("new", function()
		local o = output.new()

		assert.are.same("resty_response", o.bufname)
		assert.are.same(0, o.current_window_id)
		assert.is_nil(o.cfg.with_folding)
		assert.is_nil(o.bufnr)
		assert.is_nil(o.winnr)
		assert.is_nil(o.winbar)
	end)

	it("new with config", function()
		local o = output.new({ with_folding = true, bufname = "test" })

		assert.are.same("test", o.bufname)
		assert.are.same(0, o.current_window_id)
		assert.is_true(o.cfg.with_folding)
		assert.is_nil(o.bufnr)
		assert.is_nil(o.winnr)
		assert.is_nil(o.winbar)
	end)

	it("bufname and bufnr by win", function()
		local o = output.new():activate()

		local bufname = vim.api.nvim_buf_get_name(o.bufnr)
		assert(bufname:find(o.bufname), bufname .. " != " .. o.bufname)

		local bufnr = vim.api.nvim_win_get_buf(o.winnr)
		assert.are.same(o.bufnr, bufnr)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("activate twice", function()
		local o = output.new()
		o:activate()

		local bufname = vim.api.nvim_buf_get_name(o.bufnr)
		assert(bufname:find(o.bufname), bufname .. " != " .. o.bufname)
		local bufnr1 = o.bufnr
		assert.are.same({ "", "please wait ..." }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))

		o:activate()
		bufname = vim.api.nvim_buf_get_name(o.bufnr)
		assert(bufname:find(o.bufname), bufname .. " != " .. o.bufname)
		assert.are.not_same(o.bufnr, bufnr1)
		assert.are.same({ "", "please wait ..." }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))
	end)

	it("new and activate", function()
		local o = output.new({ with_folding = true, bufname = "test" })
		o:activate()

		assert.are.same("test", o.bufname)
		assert.are.same(0, o.current_window_id)
		assert.is_not_nil(o.bufnr)
		assert.is_not_nil(o.winnr)
		assert.is_not_nil(o.winbar)

		-- menu for winbar is correct
		assert.are.same("body", vim.tbl_get(o.winbar.menu_entries[1], "text"))
		assert.are.same("headers", vim.tbl_get(o.winbar.menu_entries[2], "text"))
		assert.are.same("info", vim.tbl_get(o.winbar.menu_entries[3], "text"))

		-- folding is default on
		assert.are.same("expr", vim.api.nvim_get_option_value("foldmethod", {}))
	end)

	it("seleclt window", function()
		local o = output.new()
		assert.is_nil(o.bufnr)
		o:activate()

		local check_show_window_content
		o.windows[99] = {
			keymap = "x",
			name = "test",
			show_window_content = function(slf)
				check_show_window_content = slf
			end,
		}

		o:show({}, { body = "{}", status = 200, headers = {} }, { duration = 1 })

		o:select_window(1)
		assert.are.same(1, o.current_window_id)

		o:select_window(2)
		assert.are.same(2, o.current_window_id)

		-- 5 is not a valid window id -> fallback to id = 1
		o:select_window(5)
		assert.are.same(1, o.current_window_id)

		o:select_window(99)
		assert.are.same(99, o.current_window_id)
		assert.are.same(99, check_show_window_content.current_window_id)

		local c = vim.api.nvim_win_get_cursor(o.winnr)
		assert.are.same({ 1, 0 }, c)
	end)

	it("show and select window", function()
		local o = output.new()
		o:activate()

		local req_def = {}
		local response = { body = '{"name": "foo"}', headers = { "accept: application/json" }, status = 200 }
		local meta = { duration = 10 }
		o:show(req_def, response, meta)

		assert.are.same("200 OK", o.meta.status_str)
		assert.are.same("10.00 s", o.meta.duration_str)

		-- show response body
		assert.are.same(1, o.current_window_id)
		assert.are.same({ "", '{"name": "foo"}' }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))

		local s = vim.wo[o.winnr].winbar
		assert(s:find("ActiveWin#body"))

		-- show response headers
		o:select_window(2)
		assert.are.same(2, o.current_window_id)
		assert.are.same({ "", "accept: application/json" }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))
		s = vim.wo[o.winnr].winbar
		assert(s:find("ActiveWin#headers"))
	end)

	it("show and pretty print with jq", function()
		local o = output.new():activate()

		local response = { body = '{"name": "foo", "valid": true}', status = 200 }
		o:show({}, response)

		-- show response body
		assert.are.same(1, o.current_window_id)
		assert.are.same({ "", '{"name": "foo", "valid": true}' }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))

		-- format json with jq
		vim.cmd("normal p")
		vim.wait(3000, function()
			return false
		end)
		assert.are.same(
			{ "", "{", '  "name": "foo",', '  "valid": true', "}" },
			vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false)
		)
	end)
end)
