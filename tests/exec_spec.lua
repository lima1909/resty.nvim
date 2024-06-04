local assert = require("luassert")
local exec = require("resty.exec")
local parser = require("resty.parser")

describe("exec:", function()
	describe("jq:", function()
		local output

		local callback = function(content)
			output = content
		end

		local function jq_with_wait(json, jq_filter)
			exec.jq(json, callback, jq_filter)
			vim.wait(15, function()
				return false
			end)
		end

		it("with default filter", function()
			jq_with_wait('{"value":true}')
			assert.are.same({ "{", '  "value": true', "}" }, output)
		end)

		it("with filter: .value", function()
			jq_with_wait('{"value":true}', ".value")
			assert.are.same({ "true" }, output)
		end)

		it("error in json", function()
			jq_with_wait('{"value":')
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

			local r = parser.parse(input, 2)

			assert.is_false(r:has_errors())
			local req_def = r.result

			local response = exec.curl(req_def)
			assert.are.same(200, response.status)
			assert.are.same("OK", response.status_str)
			assert(response.duration > 0.001, "" .. response.duration .. " > 0.001")
		end)

		it("status code", function()
			assert.are.same("OK", vim.tbl_get(exec.http_status_codes, 200))
			assert.are.same("Created", vim.tbl_get(exec.http_status_codes, 201))
			assert.are.same("Forbidden", vim.tbl_get(exec.http_status_codes, 403))
			assert.are.same(nil, vim.tbl_get(exec.http_status_codes, 999))
		end)
	end)

	describe("time-format:", function()
		it("different times", function()
			assert.are.same("100.00 s", exec.time_formated(100))
			assert.are.same("1.00 s", exec.time_formated(1))
			assert.are.same("2.30 ms", exec.time_formated(0.0023))
			assert.are.same("2.30 µs", exec.time_formated(0.0000023))
			assert.are.same("2.30 ns", exec.time_formated(0.0000000023))
		end)
	end)
end)
