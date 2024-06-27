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

	it("run and run_last", function()
		-- create an curl stub
		local curl = stub.new(exec, "curl")
		curl.invokes(function(_, callback, _)
			callback({
				body = '{"name": "foo"}',
				status = 200,
				headers = {},
			})
		end)

		-- simulate an http buffer for creating a request
		local bufnr = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"###",
			"GET https://jsonplaceholder.typicode.com/comments",
			"postId = 5",
			"id=21",
		})
		local winnr = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_cursor(winnr, { 1, 1 })

		-- call resty command RUN
		assert.are.same(0, resty.output.current_window_id)
		resty.run(bufnr)
		vim.wait(50, function()
			return false
		end)

		assert.is_true(resty.output.meta.duration > 0)

		-- show response body
		assert.are.same(1, resty.output.current_window_id)
		assert.are.same("json", vim.api.nvim_get_option_value("filetype", { buf = resty.output.bufnr }))
		assert.are.same({ "", '{"name": "foo"}' }, vim.api.nvim_buf_get_lines(resty.output.bufnr, 0, -1, false))

		-- call resty command LAST
		resty.last()
		vim.wait(50, function()
			return false
		end)

		assert.is_true(resty.output.meta.duration > 0)

		-- show response body
		assert.are.same(1, resty.output.current_window_id)
		assert.are.same("json", vim.api.nvim_get_option_value("filetype", { buf = resty.output.bufnr }))
		assert.are.same({ "", '{"name": "foo"}' }, vim.api.nvim_buf_get_lines(resty.output.bufnr, 0, -1, false))
	end)
end)
