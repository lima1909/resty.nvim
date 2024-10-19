local output = require("resty.output")
local parser = require("resty.parser")
local assert = require("luassert")
local stub = require("luassert.stub")

describe("output:", function()
	local press_key = function(key)
		vim.cmd("normal " .. key)
		vim.wait(200, function()
			return false
		end)
	end

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

		o:show({}, { body = "{}", status = 200, headers = {} })

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
		o.meta.duration = 10
		o:show(req_def, response)

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
		press_key("p")
		assert.are.same(
			{ "", "{", '  "name": "foo",', '  "valid": true', "}" },
			vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false)
		)
	end)

	it("jq query and then reset to the original", function()
		local input = stub.new(vim.fn, "input")
		input.invokes(function(_)
			return ".name"
		end)

		local o = output.new():activate()
		local response = { body = '{"name": "foo", "valid": true}', status = 200 }
		o:show({}, response)

		-- query jq
		press_key("q")
		assert.are.same({ "", '"foo"' }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))

		-- reset
		press_key("r")
		assert.are.same({ "", '{"name": "foo", "valid": true}' }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))
	end)

	it("show error", function()
		local o = output.new():activate()

		local error = {
			exit = 1,
			message = "GET ttps://jsonplaceholder.typicode.com/comments - curl error exit_code=1 stderr={ 'curl: (1) Protocol \"ttps\" not supported' }",
			stderr = "{ 'curl: (1) Protocol \"ttps\" not supported' }",
		}

		o:show_error(error)
		assert.are.same({
			"ERROR:",
			"",
			"GET ttps://jsonplaceholder.typicode.com/comments",
			"",
			'curl: (1) Protocol "ttps" not supported',
		}, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))
	end)

	it("show error with", function()
		local o = output.new():activate()
		local error = {
			exit = 1,
			message = "GET error message \n and more -",
			stderr = "{  and \n so on  }",
		}

		o:show_error(error)
		assert.are.same({
			"ERROR:",
			"",
			"GET error message  ; and more",
			"",
			"and  ; so on",
		}, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))
	end)

	it("integration: exec_and_show_response", function()
		local input = [[
### simple get 
GET https://reqres.in/api/users?page=5

]]

		local r = parser.parse(input, 2)
		local o = output.new()
		o:exec_and_show_response(r)

		-- wait of curl response
		vim.wait(7000, function()
			return 1 == o.current_window_id
		end)

		assert.is_true(o.meta.duration > 0, o.meta.duration)
		assert.are.same(o.meta.status_str, "200 OK")

		-- show response body
		assert.are.same(1, o.current_window_id)
		assert.are.same("json", vim.api.nvim_get_option_value("filetype", { buf = o.bufnr }))

		-- headers window
		press_key("h")
		assert.are.same(2, o.current_window_id)

		assert.are.same("http", vim.api.nvim_get_option_value("filetype", { buf = o.bufnr }))
		assert.are.same({ "" }, vim.api.nvim_buf_get_lines(o.bufnr, 0, 1, false))

		-- info window
		press_key("i")
		assert.are.same(3, o.current_window_id)
		assert.are.same("markdown", vim.api.nvim_get_option_value("filetype", { buf = o.bufnr }))
		assert.are.same(
			{ "## Request:", "", "```http", "GET https://reqres.in/api/users?page=5", "```" },
			vim.api.nvim_buf_get_lines(o.bufnr, 0, 5, false)
		)
	end)

	it("integration: with script", function()
		local input = [[
GET https://reqres.in/api/users/2

--{%

local json = ctx.result.body
local email = vim.json.decode(json).data.email

ctx.set("email", email)

--%} 

]]

		local r = parser.parse(input)
		local o = output.new()
		o:exec_and_show_response(r)

		-- wait of curl response
		vim.wait(7000, function()
			return 1 == o.current_window_id
		end)

		assert.are.same({ ["email"] = "janet.weaver@reqres.in" }, r.global_variables)
	end)

	it("integration: cancel exec_and_show_response", function()
		local input = [[
### simple get 
get https://reqres.in/api/users?page=5

]]

		local r = parser.parse(input, 2)

		local o = output.new()
		o:exec_and_show_response(r)

		-- cancel curl call
		press_key("cc")
		assert.are.same({ "", "curl is canceled ..." }, vim.api.nvim_buf_get_lines(o.bufnr, 0, 3, false))
	end)
end)
