local assert = require("luassert")
local e = require("resty.exec")

describe("jq:", function()
	local result
	local function get_output(output)
		result = output
	end

	it("with default filter", function()
		local j = e.__jq(get_output, '{"value":true}')
		j:start()
		j:wait()

		assert.are.same({ "{", '  "value": true', "}" }, result)
	end)

	it("with filter: .value", function()
		local j = e.__jq(get_output, '{"value":true}', ".value")
		j:start()
		j:wait()

		assert.are.same({ "true" }, result)
	end)

	it("error in json", function()
		local j = e.__jq(get_output, '{"value":')
		j:start()
		j:wait()

		assert.are.same({ "ERROR:", "", "jq: parse error: Unfinished JSON term at EOF at line 1, column 9" }, result)
	end)

	local stub = require("luassert.stub")

	it("write to buffer with mock", function()
		local mock_set_lines = stub.new(vim.api, "nvim_buf_set_lines")

		local bufnr
		local output

		mock_set_lines.invokes(function(buffer_nr, _, _, _, content)
			bufnr = buffer_nr
			output = content
			return 0
		end)

		e.jq(42, '{"value": 142}', ".value")
		vim.wait(100, function()
			return false
		end)

		assert.are.same(42, bufnr)
		assert.are.same({ "142" }, output)
	end)
end)
