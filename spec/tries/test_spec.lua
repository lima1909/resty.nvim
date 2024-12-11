local assert = require("luassert")
local test = require("resty.tries.test")
local util = require("resty.util")

describe("test-once:", function()
	local bufnr
	local lines

	before_each(function()
		local input = [[
local assert = require("luassert")

describe("test-once:", function()

  it("first", function()
    -- a comment
  end)


  it("secnd", function()
    -- a comment

  end)


  it("third", function()
    -- a comment
  end)
end)
]]
		bufnr = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_set_current_buf(bufnr)
		lines = util.input_to_lines(input)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	end)

	it("find all it functions", function()
		local its = test.find_all_it_funcs(bufnr)
		assert.are.same({ { 4, 6 }, { 9, 12 }, { 15, 17 } }, its)
	end)

	it("remove first", function()
		local its = test.find_all_it_funcs(bufnr)
		local removed = test.remove_selected_it_func(its, 4)
		assert.is_true(removed)
		assert.are.same({ { 9, 12 }, { 15, 17 } }, its)
	end)

	it("remove second", function()
		local its = test.find_all_it_funcs(bufnr)
		local removed = test.remove_selected_it_func(its, 12)
		assert.is_true(removed)
		assert.are.same({ { 4, 6 }, { 15, 17 } }, its)
	end)

	it("remove third", function()
		local its = test.find_all_it_funcs(bufnr)
		local removed = test.remove_selected_it_func(its, 16)
		assert.is_true(removed)
		assert.are.same({ { 4, 6 }, { 9, 12 } }, its)
	end)

	it("remove nothing", function()
		local its = test.find_all_it_funcs(bufnr)
		local removed = test.remove_selected_it_func(its, 7)
		assert.is_false(removed)
		assert.are.same({ { 4, 6 }, { 9, 12 }, { 15, 17 } }, its)
	end)

	it("new lines after comment out", function()
		local its = test.find_all_it_funcs(bufnr)
		local removed = test.remove_selected_it_func(its, 10)
		assert.is_true(removed)
		test.comment_it_funcs_out(its, lines)

		local result = vim.fn.join(lines, "\n")
		assert.are.same(
			[[
local assert = require("luassert")

describe("test-once:", function()

--   it("first", function()
--     -- a comment
--   end)


  it("secnd", function()
    -- a comment

  end)


--   it("third", function()
--     -- a comment
--   end)
end)
]],
			result
		)
	end)
end)
