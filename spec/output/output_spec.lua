---@diagnostic disable: param-type-mismatch
local output = require("resty.output")
local result = require("resty.parser.result")
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

	local function new_output(cfg)
		local o = output.new(cfg)
		o.bufnr, o.winnr = output._create_buf_with_win(o.bufname)
		o.curl.duration_str = "1s"
		return o
	end

	it("new", function()
		local o = output.new()

		assert.are.same("resty_response", o.bufname)
		assert.are.same(0, o.current_menu_id)
		assert.is_nil(o.cfg.with_folding)
		assert.is_nil(o.bufnr)
		assert.is_nil(o.winnr)
		assert.is_nil(o.winbar)
	end)

	it("new with config", function()
		local o = output.new({ with_folding = true, bufname = "test" })

		assert.are.same("test", o.bufname)
		assert.are.same(0, o.current_menu_id)
		assert.is_true(o.cfg.with_folding)
		assert.is_nil(o.bufnr)
		assert.is_nil(o.winnr)
		assert.is_nil(o.winbar)
	end)

	it("bufname and bufnr by win", function()
		local bufname = "test_new"
		local bufnr, winnr = output._create_buf_with_win(bufname)

		local bufname2 = vim.api.nvim_buf_get_name(bufnr)
		assert(bufname2:find(bufname), bufname .. " != " .. bufname2)

		local cbufnr = vim.api.nvim_win_get_buf(winnr)
		assert.are.same(cbufnr, bufnr)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("activate twice", function()
		local o = new_output()

		local bufname = vim.api.nvim_buf_get_name(o.bufnr)
		assert(bufname:find(o.bufname), bufname .. " != " .. o.bufname)
		local bufnr1 = o.bufnr
		assert.are.same({ "", "please wait ..." }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))

		o = new_output()
		bufname = vim.api.nvim_buf_get_name(o.bufnr)
		assert(bufname:find(o.bufname), bufname .. " != " .. o.bufname)
		assert.are.not_same(o.bufnr, bufnr1)
		assert.are.same({ "", "please wait ..." }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))
	end)

	it("show response", function()
		local o = new_output({ with_folding = true, bufname = "test" })
		o:show_response({ body = '{"name": "foo", "valid": true}', status = 200 })

		assert.are.same("test", o.bufname)
		assert.are.same(1, o.current_menu_id)
		assert.is_not_nil(o.bufnr)
		assert.is_not_nil(o.winnr)
		assert.is_not_nil(o.winbar)

		-- menu for winbar is correct
		assert.are.same("body", vim.tbl_get(o.winbar.menu_entries[1], "name"))
		assert.are.same("headers", vim.tbl_get(o.winbar.menu_entries[2], "name"))
		assert.are.same("info", vim.tbl_get(o.winbar.menu_entries[3], "name"))
	end)

	it("show error", function()
		local o = new_output()

		local error = {
			exit = 1,
			message = 'GET http://host - curl error exit_code=6 stderr={ "curl: (6) Could not resolve host: host" }',
			stderr = "{  and \n so on  }",
		}

		o:show_error(error)

		assert.are.same("error", vim.tbl_get(o.winbar.menu_entries[1], "name"))
		assert.are.same("info", vim.tbl_get(o.winbar.menu_entries[2], "name"))

		assert.are.same({ "", "# curl error", "" }, vim.api.nvim_buf_get_lines(o.bufnr, 0, 3, false))
	end)

	it("show dry run", function()
		local o = new_output()
		local job = {
			"-sSL",
			"-D",
			"/run/user/1000//plenary_curl_4f6b47cf.headers",
			"--compressed",
			"-X",
			"GET",
			"-H",
			"Accept: application/json",
			"http://host",
		}

		o:show_dry_run(job)

		assert.are.same(6, o.current_menu_id)
		assert.is_not_nil(o.bufnr)
		assert.is_not_nil(o.winnr)
		assert.is_not_nil(o.winbar)

		-- winbar
		assert.are.same("dry_run", vim.tbl_get(o.winbar.menu_entries[1], "name"))
		assert.are.same("info", vim.tbl_get(o.winbar.menu_entries[2], "name"))

		assert.are.same({ "", "# curl dry run", "" }, vim.api.nvim_buf_get_lines(o.bufnr, 0, 3, false))
	end)

	it("select different windows", function()
		local o = new_output()
		o.parse_result = result.new()
		o.parse_result.request.url = "http://host"
		o:show_dry_run({ "-X", "GET", "http://host" })

		o:select_window(3)
		assert.are.same(3, o.current_menu_id)
		o:select_window(6)
		assert.are.same(6, o.current_menu_id)

		-- 100 is not a valid window id -> fallback to id = 1
		o:select_window(100)
		assert.are.same(6, o.current_menu_id)

		-- new show with new menu-ids
		o:show_response({ body = "{}", status = 200, headers = {} })

		o:select_window(1)
		assert.are.same(1, o.current_menu_id)
		o:select_window(2)
		assert.are.same(2, o.current_menu_id)

		-- 100 is not a valid window id -> fallback to id = 1
		o:select_window(100)
		assert.are.same(1, o.current_menu_id)

		-- window exits
		local c = vim.api.nvim_win_get_cursor(o.winnr)
		assert.are.same({ 1, 0 }, c)
	end)

	it("show and select window", function()
		local response = { body = '{"name": "foo"}', headers = { "accept: application/json" }, status = 200 }

		local o = new_output()
		o:show_response(response)

		-- show response body
		assert.are.same(1, o.current_menu_id)
		assert.are.same({ "", '{"name": "foo"}' }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))

		local s = vim.wo[o.winnr].winbar
		assert(s:find("ActiveWin#body"))

		-- show response headers
		o:select_window(2)
		assert.are.same(2, o.current_menu_id)
		assert.are.same({ "", "accept: application/json" }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))
		s = vim.wo[o.winnr].winbar
		assert(s:find("ActiveWin#headers"))
	end)

	it("show and pretty print with jq", function()
		local o = new_output()

		local response = { body = '{"name": "foo", "valid": true}', status = 200 }
		o:show_response(response)

		-- show response body
		assert.are.same(1, o.current_menu_id)
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

		local o = new_output()

		local response = { body = '{"name": "foo", "valid": true}', status = 200 }
		o:show_response(response)

		-- query jq
		press_key("q")
		assert.are.same({ "", '"foo"' }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))

		-- reset
		press_key("r")
		assert.are.same({ "", '{"name": "foo", "valid": true}' }, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))
	end)

	it("show error", function()
		local o = new_output()

		local error = {
			exit = 1,
			message = "GET ttps://jsonplaceholder.typicode.com/comments - curl error exit_code=1 stderr={ 'curl: (1) Protocol \"ttps\" not supported' }",
			stderr = "{ 'curl: (1) Protocol \"ttps\" not supported' }",
		}

		o:show_error(error)
		assert.are.same({
			"",
			"# curl error",
			"",
			"",
			"```sh",
			"GET ttps://jsonplaceholder.typicode.com/comments",
			"",
			"stderr={ 'curl: (1) Protocol \"ttps\" not supported' }",
			"exit_code=1 ",
			"```",
			"",
		}, vim.api.nvim_buf_get_lines(o.bufnr, 0, -1, false))
	end)

	it("show invalid error message", function()
		local o = new_output()

		local error = {
			exit = 1,
			message = "GET error message \n and more -",
			stderr = "{  and \n so on  }",
		}

		o:show_error(error)
		assert.are.same({ "", "# curl error", "" }, vim.api.nvim_buf_get_lines(o.bufnr, 0, 3, false))
	end)

	it("integration: exec_and_show_response", function()
		local input = [[
### simple get 
GET https://reqres.in/api/users?page=5
x-api-key: reqres-free-v1

]]

		local r = parser.parse(input, 2)
		local o = output.new()
		o:exec_and_show_response(r)

		-- wait of curl response
		vim.wait(7000, function()
			return 1 == o.current_menu_id
		end)

		assert.is_true(o.curl.duration > 0, o.curl.duration)

		-- show response body
		assert.are.same(1, o.current_menu_id)
		assert.are.same("json", vim.api.nvim_get_option_value("filetype", { buf = o.bufnr }))

		-- headers window
		press_key("h")
		assert.are.same(2, o.current_menu_id)

		assert.are.same("http", vim.api.nvim_get_option_value("filetype", { buf = o.bufnr }))
		assert.are.same({ "" }, vim.api.nvim_buf_get_lines(o.bufnr, 0, 1, false))

		-- info window
		press_key("i")
		assert.are.same(3, o.current_menu_id)
		assert.are.same("markdown", vim.api.nvim_get_option_value("filetype", { buf = o.bufnr }))
		assert.are.same({
			"",
			"## Request:",
			"",
			"```http",
			"GET https://reqres.in/api/users?page=5",
			"x-api-key: reqres-free-v1",
			"```",
			"",
		}, vim.api.nvim_buf_get_lines(o.bufnr, 0, 8, false))
	end)

	it("integration: with script", function()
		local input = [[
GET https://reqres.in/api/users/2
x-api-key: reqres-free-v1

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
			return 1 == o.current_menu_id
		end)

		assert.are.same({ ["email"] = "janet.weaver@reqres.in" }, r.global_variables)
	end)

	it("integration: cancel exec_and_show_response", function()
		local input = [[
### simple get 
GET https://reqres.in/api/users?page=5
x-api-key: reqres-free-v1

]]

		local r = parser.parse(input, 2)

		local o = output.new()
		o:exec_and_show_response(r)

		-- cancel curl call
		press_key("cc")
		assert.are.same({ "", "curl is canceled ..." }, vim.api.nvim_buf_get_lines(o.bufnr, 0, 3, false))
	end)

	it("integration: with timeout", function()
		local input = [[
### simple get with timeout
@cfg.timeout = 3 

GET https://api.restful-api.dev/objects?id=1&id=6

]]

		local r = parser.parse(input, 2)
		local o = output.new()
		o:exec_and_show_response(r)

		-- wait of curl response
		vim.wait(1000, function()
			return 7 == o.current_menu_id
		end)

		assert.are.same({ "", "curl is timed out after: 3 ms" }, vim.api.nvim_buf_get_lines(o.bufnr, 0, 2, false))
	end)

	it("integration: with timeout longer then the call", function()
		local input = [[
### simple get with timeout
@cfg.timeout = 5000 # 5second 

GET https://reqres.in/api/users?page=5
x-api-key: reqres-free-v1

]]

		local r = parser.parse(input, 2)
		local o = output.new()
		o:exec_and_show_response(r)

		assert.are.same({ "", "please wait ..." }, vim.api.nvim_buf_get_lines(o.bufnr, 0, 2, false))

		-- wait of curl response
		vim.wait(7000, function()
			return 1 == o.current_menu_id
		end)

		assert.are.same({
			"",
			'{"page":5,"per_page":6,"total":12,"total_pages":2,"data":[],"support":{"url":"https://contentcaddy.io?utm_source=reqres&utm_medium=json&utm_campaign=referral","text":"Tired of writing endless social media content? Let Content Caddy generate it for you."}}',
		}, vim.api.nvim_buf_get_lines(o.bufnr, 0, 2, false))
	end)
end)
