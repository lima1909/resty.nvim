local assert = require("luassert")
local cmd = require("resty.commands")

describe("commands:", function()
	describe("complete_cmd:", function()
		it("empty", function()
			assert.are.same(cmd.COMMANDS, cmd.complete_cmd(""))
			assert.are.same(cmd.COMMANDS, cmd.complete_cmd(" "))
			assert.are.same(cmd.COMMANDS, cmd.complete_cmd("   "))
			assert.are.same(cmd.COMMANDS, cmd.complete_cmd("\t"))
		end)

		it("not found", function()
			assert.are.same(cmd.COMMANDS, cmd.complete_cmd("x"))
		end)

		it("found", function()
			assert.are.same({ cmd.CMD_RUN }, cmd.complete_cmd("r"))
			assert.are.same({ cmd.CMD_RUN }, cmd.complete_cmd("ru"))
			assert.are.same({ cmd.CMD_RUN }, cmd.complete_cmd("run"))

			assert.are.same({ cmd.CMD_FAVORITE }, cmd.complete_cmd("f"))

			assert.are.same({ cmd.CMD_LAST }, cmd.complete_cmd("l"))
		end)
	end)

	describe("complete:", function()
		local bufnr

		before_each(function()
			bufnr = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"### #first",
				"GET http://host.com",
				"",
				"### #next one",
				"GET http://host.com",
				"",
				"### #next one one",
				"GET http://host.com",
			})
		end)

		it("empty", function()
			assert.are.same(cmd.COMMANDS, cmd.complete("", "Resty "))
			assert.are.same(cmd.COMMANDS, cmd.complete("xyz", "Resty "))
		end)

		it("run", function()
			assert.are.same({}, cmd.complete("", "Resty run"))
			assert.are.same({ cmd.CMD_RUN }, cmd.complete("r", "Resty "))
			assert.are.same({ cmd.CMD_RUN }, cmd.complete("ru", "Resty "))
		end)

		it("last", function()
			assert.are.same({}, cmd.complete("", "Resty run"))
			assert.are.same({ cmd.CMD_LAST }, cmd.complete("l", "Resty "))
			assert.are.same({ cmd.CMD_LAST }, cmd.complete("la", "Resty "))
		end)

		it("favorite", function()
			assert.are.same({ "first", "next one", "next one one" }, cmd.complete("", "Resty favorite"))
			assert.are.same({ "first" }, cmd.complete("f", "Resty favorite"))
			assert.are.same({ "next one", "next one one" }, cmd.complete("ne", "Resty favorite"))

			assert.are.same({}, cmd.complete("xyz", "Resty favorite"))
		end)
	end)
end)
