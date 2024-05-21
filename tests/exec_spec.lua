local assert = require("luassert")
local stub = require("luassert.stub")
local exec = require("resty.exec")
local parser = require("resty.parser")

describe("exec:", function()
	describe("jq:", function()
		local mock_set_lines = stub.new(vim.api, "nvim_buf_set_lines")

		local bufnr
		local output

		mock_set_lines.invokes(function(buffer_nr, _, _, _, content)
			bufnr = buffer_nr
			output = content
			return 0
		end)

		local function jq_with_wait(bnr, json, jq_filter)
			exec.jq(bnr, json, jq_filter)
			vim.wait(15, function()
				return false
			end)
		end

		it("with default filter", function()
			jq_with_wait(1, '{"value":true}')
			assert.are.same(1, bufnr)
			assert.are.same({ "{", '  "value": true', "}" }, output)
		end)

		it("with filter: .value", function()
			jq_with_wait(1, '{"value":true}', ".value")
			assert.are.same(1, bufnr)
			assert.are.same({ "true" }, output)
		end)

		it("error in json", function()
			jq_with_wait(1, '{"value":')
			assert.are.same(1, bufnr)
			assert(output[1]:find("ERROR:"), output[1])
			assert(output[2]:find(""), output[2])
			assert(output[3]:find("Unfinished JSON term at EOF at line 1, column 9"), output[3])
		end)
	end)

	describe("curl:", function()
		it("simple GET request", function()
			local input = [[
### simple get 
Get https://httpbin.org/get 

]]

			local req_def = parser.parse(input)[1]
			local response, ms = exec.curl(req_def)
			assert.are.same(200, response.status)
			assert(ms > 1, "" .. ms .. " > 1")
		end)
	end)
end)
