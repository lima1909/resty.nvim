local assert = require("luassert")
local exec = require("resty.exec")
local parser = require("resty.parser")

describe("exec:", function()
	describe("jq:", function()
		local output

		local callback = function(content)
			output = content
		end

		it("with default filter", function()
			exec.jq_wait(2000, '{"value":true}', callback)
			assert.are.same({ "{", '  "value": true', "}" }, output)
		end)

		it("with filter: .value", function()
			exec.jq_wait(2000, '{"value":true}', callback, ".value")
			assert.are.same({ "true" }, output)
		end)

		it("error in json", function()
			exec.jq_wait(2000, '{"value":', callback)
			assert(output[1]:find("ERROR:"), output[1])
			assert(output[2]:find(""), output[2])
			assert(output[3]:find("Unfinished JSON term at EOF at line 1, column 9"), output[3])
		end)
	end)

	describe("curl:", function()
		local response
		local callback = function(r)
			response = r
		end

		local error
		local error_fn = function(e)
			error = e
		end

		it("simple GET request", function()
			local input = [[
### simple get 
Get https://httpbin.org/get 

]]

			local r = parser.parse(input, 2)
			assert.is_false(r:has_errors())

			local req_def = r.result
			exec.curl_wait(3000, req_def, callback, error_fn)

			assert.is_nil(error)
			assert.are.same(200, response.status)
		end)

		it("request error: bad url", function()
			local input = [[
### 
Get https://.org/get 

]]

			local r = parser.parse(input, 2)
			assert.is_false(r:has_errors())

			local req_def = r.result
			exec.curl_wait(3000, req_def, callback, error_fn)

			assert.is_not_nil(error)
			assert.are.same(6, error.exit)
			local err_msg = "Could not resolve host: .org"
			assert(error.stderr:find(err_msg), err_msg)
		end)
	end)
end)
