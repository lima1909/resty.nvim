describe("parse:", function()
	local p = require("resty.parser")
	local assert = require("luassert")

	it("error for empty input", function()
		local input = [[
		]]

		local _, err = pcall(p.parse, input, 1)
		assert(err:find("no request found"))
	end)

	it("error for empty request", function()
		local input = [[
### 
		]]

		local result = p.parse(input, 1)

		assert.is_true(result:has_errors())
		assert.are.same(1, #result.errors)

		local err_msg = result.errors[1].message
		assert(err_msg:find("expected two parts: method and url"))
	end)

	it("error missing method and url", function()
		local input = [[
###
# POST https://api.restful-api.dev/objects

accept: application/json  

]]

		local result = p.parse(input, 1)

		assert.is_true(result:has_errors())
		assert.are.same(1, #result.errors)

		local err_msg = result.errors[1].message
		assert(err_msg:find("invalid method name: 'accept:'. Only letters are allowed"))
	end)

	it("error body without method and url", function()
		local input = [[
### 
{
"name": "foo"
}
]]

		local r = p.parse(input, 2)

		assert.is_true(r:has_errors())
		assert.are.same(1, #r.errors)

		local err_msg = r.errors[1].message
		assert(err_msg:find("expected two parts: method and url"))
	end)

	it("error check line_nr", function()
		local input = [[
### 
Get https://httpbin.org/get 

# query without value
foo=
		]]

		local result = p.parse(input, 3)

		assert.is_true(result:has_errors())
		assert.are.same(1, #result.errors)

		local err_msg = result.errors[1].message
		assert(err_msg:find("an empty value is not allowed"), err_msg)

		local line_nr = result.errors[1].lnum
		assert.are.same(4, line_nr)
	end)

	it("no name request", function()
		local input = [[
### 
Get https://httpbin.org/get 

]]

		local r = p.parse(input, 1)

		assert.is_false(r:has_errors())
		local result = r.result

		assert.are.same(result, {
			req = {
				method = "GET",
				url = "https://httpbin.org/get",
				headers = {},
				query = {},
			},
		})
	end)

	it("more chars after the request", function()
		local input = [[
### 
Get https://httpbin.org/get 

---

head:val

query=val

]]

		local r = p.parse(input, 1)

		assert.is_false(r:has_errors())
		local result = r.result

		assert.are.same(result, {
			req = {
				method = "GET",
				url = "https://httpbin.org/get",
				headers = {},
				query = {},
			},
		})
	end)

	it("spaces between method and url", function()
		local input = [[
### 
GET   https://jsonplaceholder.typicode.com/comments
 
---
]]

		local r = p.parse(input, 1)

		assert.is_false(r:has_errors())
		local result = r.result

		assert.are.same(result, {
			req = {
				method = "GET",
				url = "https://jsonplaceholder.typicode.com/comments",
				headers = {},
				query = {},
			},
		})
	end)

	it("header with eq char", function()
		local input = [[
### 
GET   https://jsonplaceholder.typicode.com/comments

foo: bar=
]]

		local r = p.parse(input, 2)

		assert.is_false(r:has_errors())
		local result = r.result

		assert.are.same(result, {
			req = {
				method = "GET",
				url = "https://jsonplaceholder.typicode.com/comments",
				headers = { foo = "bar=" },
				query = {},
			},
		})
	end)

	it("multi reqest definitions", function()
		local input = [[
### 
GET   https://jsonplaceholder.typicode.com/comments

### 
GET https://httpbin.org/get 

]]

		local r = p.parse(input, 2)

		assert.is_false(r:has_errors())
		local result = r.result

		assert.are.same(result, {
			req = {
				method = "GET",
				url = "https://jsonplaceholder.typicode.com/comments",
				headers = {},
				query = {},
			},
		})

		r = p.parse(input, 5)

		assert.is_false(r:has_errors())
		result = r.result

		assert.are.same(result, {
			req = {
				method = "GET",
				url = "https://httpbin.org/get",
				headers = {},
				query = {},
			},
		})
	end)

	it("request with comments", function()
		local input = [[
### 
GET   https://jsonplaceholder.typicode.com/comments

#foo: bar
# foo: bar

# foo = bar
#foo = bar
]]

		local r = p.parse(input, 2)

		assert.is_false(r:has_errors())
		local result = r.result

		assert.are.same(result, {
			req = {
				method = "GET",
				url = "https://jsonplaceholder.typicode.com/comments",
				headers = {},
				query = {},
			},
		})
	end)

	it("replace variable", function()
		local variables = { ["host"] = "my-host" }

		local tt = {
			-- input = output (expected)
			{ input = "host}}", err_msg = "missing open brackets: '{{'" },
			{ input = "{{host}}.port}}", err_msg = "missing open brackets: '{{'" },
			{ input = "{{host", err_msg = "missing closing brackets: '}}'" },
			{ input = "{{host}}.{{port", err_msg = "missing closing brackets: '}}'" },
			{ input = "{{FOO}}", err_msg = "no variable found with name: 'FOO'" },

			{ input = "host}", expected = "host}" },
			{ input = "{host", expected = "{host" },
			{ input = "{host}", expected = "{host}" },
			{ input = "{{host}}", expected = "my-host" },
			{ input = "http://{{host}}", expected = "http://my-host" },
			{ input = "{{host}}.de", expected = "my-host.de" },
			{ input = "http://{{host}}.de", expected = "http://my-host.de" },
		}

		for _, tc in ipairs(tt) do
			local line, err = p.replace_variable(variables, tc.input)
			if err then
				assert.are.same(tc.err_msg, err)
			else
				assert.are.same(tc.expected, line)
			end
		end
	end)

	it("comment in line", function()
		local tt = {
			{ input = "host ", expected = "host " },
			{ input = "host # comment", expected = "host " },
			{ input = "host# comment", expected = "host" },
			{ input = "host#", expected = "host" },
			{ input = "# host# comment", expected = "" },
		}
		for _, tc in ipairs(tt) do
			local line = p.cut_comment(tc.input)
			assert.are.same(tc.expected, line)
		end
	end)

	it("request with headers and queries", function()
		local input = [[
### 
Get https://httpbin.org/get 

accept: application/json  
Authorization: Bearer mytoken123

filter = id = "42" and age > 42
include = sub, *  

]]

		local r = p.parse(input, 2)

		assert.is_false(r:has_errors())
		local result = r.result

		assert.are.same(result, {
			req = {
				method = "GET",
				url = "https://httpbin.org/get",
				headers = {
					accept = "application/json",
					Authorization = "Bearer mytoken123",
				},
				query = {
					filter = 'id = "42" and age > 42',
					include = "sub, *",
				},
			},
		})
	end)

	it("request with headers and queries and body", function()
		local input = [[
### 
Get https://httpbin.org/get 
accept: application/json 
filter = id = "42" and age > 42

{
	"name": "foo",
	"valid" : true
}
]]

		local r = p.parse(input, 2)

		assert.is_false(r:has_errors())
		local result = r.result

		assert.are.same(result, {
			req = {
				method = "GET",
				url = "https://httpbin.org/get",
				headers = {
					accept = "application/json",
				},
				query = {
					filter = 'id = "42" and age > 42',
				},
				body = [[{	"name": "foo",	"valid" : true}]],
			},
		})
	end)

	it("body, simple", function()
		local input = [[
### 
Get https://host
{
"name": "foo"
}
]]

		local r = p.parse(input, 2)
		assert.are.same(r.result, {
			req = {
				method = "GET",
				url = "https://host",
				headers = {},
				query = {},
				body = '{"name": "foo"}',
			},
		})
	end)
end)
