local assert = require("luassert")
local c = require("resty.parser.curl")

-- curl -sSL -D /run/user/1000//plenary_curl_43304f42.headers --insecure --compressed -X POST -H Content-Type: application/json ; charset=utf-8 -H Accept: application/json --data-raw { "userId": 1, "title": "my title", "body": "my body" } https://jsonplaceholder.typicode.com/posts

describe("basics for the parser:", function()
	it("until", function()
		local p = c.new()
		p.current_line = "foo' "
		assert.are.same("foo", p:next_until("'"))
		assert.are.same(5, p.c)

		p = c.new()
		p.current_line = 'foo" '
		assert.are.same("foo", p:next_until('"'))
		assert.are.same(5, p.c)

		p = c.new()
		p.current_line = 'foo " '
		assert.are.same("foo ", p:next_until('"'))
		assert.are.same(6, p.c)

		p = c.new()
		p.current_line = "foo "
		assert.are.same("foo", p:next_until(" "))
		assert.are.same(5, p.c)
	end)

	it("between", function()
		local p = c.new()
		p.current_line = "'foo' "
		assert.are.same("foo", p:between())
		assert.are.same(6, p.c)

		p = c.new()
		p.current_line = '"foo" '
		assert.are.same("foo", p:between())
		assert.are.same(6, p.c)

		p = c.new()
		p.current_line = '"foo " '
		assert.are.same("foo ", p:between())
		assert.are.same(7, p.c)

		p = c.new()
		p.current_line = " foo  "
		assert.are.same("foo", p:between())
		assert.are.same(6, p.c)
	end)
end)

describe("curl-parser:", function()
	it("only url, no method", function()
		local curl_cmd = ">curl		 http://localhost"
		local r = c.parse_curl_cmd(curl_cmd)
		assert.are.same(r.request, { url = "http://localhost", method = "GET" })
	end)

	it("only url, no method, with insecure", function()
		local curl_cmd = ">curl --insecure https://localhost"
		local req = c.parse_curl_cmd(curl_cmd).request
		assert.are.same(req, { url = "https://localhost", method = "GET", insecure = true })
	end)

	it("url and method, ignore sSL", function()
		local curl_cmd = ">curl -sSL -X POST https://localhost"
		local req = c.parse_curl_cmd(curl_cmd).request
		assert.are.same(req, { url = "https://localhost", method = "POST" })

		-- long version of request
		curl_cmd = ">curl https://localhost   -sSL --request POST "
		req = c.parse_curl_cmd(curl_cmd).request
		assert.are.same(req, { url = "https://localhost", method = "POST" })
	end)

	it("multi-line input", function()
		local curl_cmd = ">curl -X delete \n https://localhost"
		local r = c.parse_curl_cmd(curl_cmd)
		assert.are.same(r.request, { url = "https://localhost", method = "DELETE" })
	end)

	it("url and method, where url in quotes", function()
		local curl_cmd = ">curl -X patch 'https://my-host?id = 7'"
		local req = c.parse_curl_cmd(curl_cmd).request
		assert.are.same(req, { url = "https://my-host?id = 7", method = "PATCH" })
	end)

	it("with headers", function()
		local curl_cmd =
			'>curl -H "Content-Type: application/json ; charset=utf-8" -H "Accept: application/json" http://localhost'
		local r = c.parse_curl_cmd(curl_cmd)
		assert.are.same(r.request, {
			url = "http://localhost",
			method = "GET",
			headers = {
				["Content-Type"] = "application/json ; charset=utf-8",
				["Accept"] = "application/json",
			},
		})

		-- long version of headers
		curl_cmd = '>curl http://localhost  --header "Accept: application/json" '
		r = c.parse_curl_cmd(curl_cmd)
		assert.are.same(r.request, {
			url = "http://localhost",
			method = "GET",
			headers = { ["Accept"] = "application/json" },
		})
	end)

	it("with headers, without space in between", function()
		local curl_cmd = ">curl -H Accept:application/json http://localhost"
		local req = c.parse_curl_cmd(curl_cmd).request
		assert.are.same(req, {
			url = "http://localhost",
			method = "GET",
			headers = { ["Accept"] = "application/json" },
		})
	end)

	it("with headers with double :", function()
		local curl_cmd = ">curl -H 'Foo: bar:baz' http://localhost"
		local req = c.parse_curl_cmd(curl_cmd).request
		assert.are.same(req, {
			url = "http://localhost",
			method = "GET",
			headers = { ["Foo"] = "bar:baz" },
		})
	end)

	it("with body and quotes", function()
		local curl_cmd = [[>curl -H "Accept: application/json" http://localhost --data-raw "{'name': 'Paul'}"]]
		local req = c.parse_curl_cmd(curl_cmd).request
		assert.are.same(req, {
			url = "http://localhost",
			method = "GET",
			headers = { ["Accept"] = "application/json" },
			body = "{'name': 'Paul'}",
		})

		curl_cmd = [[>curl http://localhost --data '{"name": "Paul"}']]
		req = c.parse_curl_cmd(curl_cmd).request
		assert.are.same(req, { url = "http://localhost", method = "GET", body = '{"name": "Paul"}' })

		curl_cmd = [[>curl http://localhost --json '{"name": "Paul"}']]
		req = c.parse_curl_cmd(curl_cmd).request
		assert.are.same(req, { url = "http://localhost", method = "GET", body = '{"name": "Paul"}' })

		curl_cmd = [[>curl http://localhost -d '{"name": "Paul"}']]
		req = c.parse_curl_cmd(curl_cmd).request
		assert.are.same(req, { url = "http://localhost", method = "GET", body = '{"name": "Paul"}' })
	end)
end)

-- describe("curl-parser-error:", function()
-- 	it("url and method, only with beginning quotes", function()
-- 		local curl_cmd = { ">curl ", "'https://localhost?id = 7 -X patch" }
-- 		local r = c.parse_curl_cmd(curl_cmd)
--
-- 		assert.is_true(r:has_error())
-- 		assert.are.same(2, #r:errors())
--
-- 		local err = r:errors()[1]
-- 		assert.are.same("could not found termination character: ' https://localhost?id = 7 -X patch", err.message)
-- 		assert.are.same(1, err.lnum)
--
-- 		err = r:errors()[2]
-- 		assert.are.same("no url found", err.message)
-- 		assert.are.same(0, err.lnum)
-- 		assert.are.same(1, err.end_lnum)
-- 	end)
-- end)
