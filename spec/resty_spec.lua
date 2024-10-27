local resty = require("resty")
local exec = require("resty.exec")
local assert = require("luassert")
local stub = require("luassert.stub")

describe("resty:", function()
	it("default setup", function()
		resty.setup({})
		assert.is_true(resty.config.response.with_folding)
		assert.are.same("resty_response", resty.config.response.bufname)
	end)

	it("setup", function()
		resty.setup({ response = { with_folding = false, bufname = "foo" } })
		assert.is_false(resty.config.response.with_folding)
		assert.are.same("foo", resty.config.response.bufname)
	end)

	-- create an curl stub
	local curl = stub.new(exec, "curl")

	-- mock the curl call
	curl.invokes(function(_, callback, _)
		callback({
			body = '{"name": "foo"}',
			status = 200,
			headers = {},
			global_variables = {},
		})

		-- returns a dummy metatable, else the exec function interpreted the call as dry-run
		return setmetatable({}, { __index = {} })
	end)

	it("_run and run_last", function()
		assert.are.same(0, resty.output.current_menu_id)

		-- call resty command RUN
		resty._run({
			"###",
			"GET https://dummy",
			"postId = 5",
			"id=21",
		})
		vim.wait(50, function()
			return false
		end)

		assert.is_true(resty.output.curl.duration > 0)

		-- show response body
		assert.are.same(1, resty.output.current_menu_id)
		assert.are.same("json", vim.api.nvim_get_option_value("filetype", { buf = resty.output.bufnr }))
		assert.are.same({ "", '{"name": "foo"}' }, vim.api.nvim_buf_get_lines(resty.output.bufnr, 0, -1, false))

		-- call resty command LAST
		resty.last()
		vim.wait(50, function()
			return false
		end)

		assert.is_true(resty.output.curl.duration > 0)

		-- show response body
		assert.are.same(1, resty.output.current_menu_id)
		assert.are.same("json", vim.api.nvim_get_option_value("filetype", { buf = resty.output.bufnr }))
		assert.are.same({ "", '{"name": "foo"}' }, vim.api.nvim_buf_get_lines(resty.output.bufnr, 0, -1, false))
	end)

	it("run input", function()
		resty.run("GET http://dummy\n id = 7")
		vim.wait(50, function()
			return false
		end)

		-- no parse errors
		assert.are.same({}, resty.output.parse_result.diagnostics)

		assert.is_true(resty.output.curl.duration > 0)

		-- show response body
		assert.are.same(1, resty.output.current_menu_id)
		assert.are.same("json", vim.api.nvim_get_option_value("filetype", { buf = resty.output.bufnr }))
		assert.are.same({ "", '{"name": "foo"}' }, vim.api.nvim_buf_get_lines(resty.output.bufnr, 0, -1, false))
	end)
end)
