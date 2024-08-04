local assert = require("luassert")
local exec = require("resty.exec")
local parser = require("resty.parser")

describe("exec:", function()
	describe("jq:", function()
		local output
		local code

		local callback = function(content, c)
			output = content
			code = c
		end

		it("with default filter", function()
			exec.jq_wait(2000, '{"value":true}', callback)
			assert.are.same({ "{", '  "value": true', "}" }, output)
			assert.are.same(0, code)
		end)

		it("with filter: .value", function()
			exec.jq_wait(2000, '{"value":true}', callback, ".value")
			assert.are.same({ "true" }, output)
			assert.are.same(0, code)
		end)

		it("error in json", function()
			exec.jq_wait(2000, '{"value":', callback)
			assert(output[1]:find("ERROR:"), output[1])
			assert(output[2]:find(""), output[2])
			assert(output[3]:find("Unfinished JSON term at EOF at line 1, column 9"), output[3])
			assert.is_true(0 ~= code, code)
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
GET https://reqres.in/api/users?page=5

]]

			local r = parser.parse(input, 2)
			assert.is_false(r:has_errors())

			exec.curl_wait(7000, r.request, callback, error_fn)

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

			exec.curl_wait(7000, r.request, callback, error_fn)

			assert.is_not_nil(error)
			assert.are.same(6, error.exit)
			local err_msg = "Could not resolve host: .org"
			assert(error.stderr:find(err_msg), err_msg)
		end)
	end)

	describe("stop time", function()
		local nix = function(a, b, c)
			return a, b, c
		end

		it("exec_with_stop_time", function()
			local one, a, b, duration = exec.exec_with_stop_time(nix, 1, "a", true)
			assert.are.same(1, one)
			assert.are.same("a", a)
			assert.are.same(true, b)
			assert.is_true(duration > 0, duration)
		end)
	end)

	describe("exec command", function()
		it("echo 'test output'", function()
			local output = exec.cmd('echo "test output"')
			assert.are.same("test output\n", output)
		end)

		it("command fail", function()
			local output = exec.cmd('ech "test output"')
			assert.is_true(output:find("ech") > 0)
			assert.is_true(output:find("not found") > 0)
		end)
	end)
end)
