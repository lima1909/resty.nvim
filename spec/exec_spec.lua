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
			local found_jq = exec.jq_wait(2000, '{"value":true}', callback)
			assert.is_true(found_jq)
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
			assert(output[1]:find("ERROR in parsing json with jq:"), output[1])
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

		it("json from file", function()
			local input = {
				"POST https://api.restful-api.dev/objects",
				"Accept: application/json",
				"Content-type: application/json ; charset=utf-8",
				"",
				"< ./spec/parser/test.json",
			}

			local r = parser.parse(input, 1)
			assert.is_false(r:has_diag())

			exec.curl_wait(7000, r.request, callback, error_fn)

			assert.is_nil(error)

			local resp = vim.json.decode(response.body)
			assert.are.same("MY Apple MacBook Pro 4", resp.name)
			assert.are.same(2019, resp.data.year)
		end)

		it("simple GET request", function()
			local input = [[
### simple get 
GET https://reqres.in/api/users?page=5
x-api-key: reqres-free-v1

Accept: application/json
Content-type: application/json ; charset=utf-8

]]

			local r = parser.parse(input, 2)
			assert.is_false(r:has_diag())

			exec.curl_wait(7000, r.request, callback, error_fn)

			assert.is_nil(error)
			assert.are.same(200, response.status)
		end)

		it("request error: bad url", function()
			local input = [[
### 
GET https://.org/get 

]]

			local r = parser.parse(input, 2)
			assert.is_false(r:has_diag())

			exec.curl_wait(7000, r.request, callback, error_fn)

			assert.is_not_nil(error)
			assert.are.same(6, error.exit)
			local err_msg = "Could not resolve host: .org"
			assert(error.stderr:find(err_msg), err_msg)

			-- reset error
			error = nil
		end)

		it("with script, json body", function()
			local input = [[
GET https://reqres.in/api/users/2
x-api-key: reqres-free-v1

--{%
  local json = ctx.json_body()
  ctx.set("id", json.data.id)
--%}
]]

			local r = parser.parse(input)
			assert.is_false(r:has_diag())

			exec.curl_wait(7000, r.request, callback, error_fn)

			assert.are.same(200, response.status)
			assert.are.same("2", response.global_variables["id"])
		end)

		it("with script, jq body", function()
			local input = [[
GET https://reqres.in/api/users/3
x-api-key: reqres-free-v1

--{%
  local id = ctx.jq_body('.data.id')
  ctx.set("id", id)
--%}
]]

			local r = parser.parse(input)
			assert.is_false(r:has_diag())

			exec.curl_wait(7000, r.request, callback, error_fn)

			assert.are.same(200, response.status)
			assert.are.same("3", response.global_variables["id"])
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

			local pos_found = string.find(output, "not found") or 0
			local pos_found_de = string.find(output, "nicht gefunden") or 0
			assert.is_true(pos_found > 0 or pos_found_de > 0)
		end)
	end)

	describe("sript:", function()
		it("empty", function()
			local ctx = exec.script("")
			assert.are.same({}, ctx)
		end)

		it("no script", function()
			local ctx = exec.script("\n")
			assert.are.same({}, ctx)
		end)

		it("simple", function()
			local ctx = exec.script(
				[[
--{%
  ctx.set("my-foo", ctx.result.name.."bar")
--%}
			]],
				{ name = "foo" }
			)
			assert.are.same("foobar", ctx["my-foo"])
		end)

		it("json body", function()
			local ctx = exec.script(
				[[
--{%
  local name = ctx.json_body().name
  ctx.set("foo", name)
--%}
			]],
				{ body = '{ "name": "foo"}' }
			)
			assert.are.same("foo", ctx["foo"])
		end)

		it("with error", function()
			local _, err = pcall(
				exec.script,
				[[
--{%
  ctx.set("my-foo", )
--%}
			]],
				{ name = "foo" }
			)
			assert.are.same([[[string "script error"]:2: unexpected symbol near ')']], err)
		end)
	end)
end)
