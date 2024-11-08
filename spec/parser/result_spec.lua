local assert = require("luassert")
local p = require("resty.parser")
local result = require("resty.parser.result")

describe("valid variable row:", function()
	it("only variable", function()
		local r = p.parse({
			"@a=b",
		}, 1)

		assert.is_true(r:is_valid_variable_row(1))
		assert.is_false(r:is_valid_variable_row(2))
	end)

	it("global variable", function()
		local r = p.parse({
			"@a=b",
			"",
			"@c=d",
			"###",
		}, 1)

		assert.is_true(r:is_valid_variable_row(1))
		assert.is_true(r:is_valid_variable_row(2))
		assert.is_true(r:is_valid_variable_row(3))

		assert.is_false(r:is_valid_variable_row(0))
		assert.is_false(r:is_valid_variable_row(4))
	end)

	it("variable before request", function()
		local r = p.parse({
			"@a=b",
			"",
			"@c=d",
			"GET http://host",
		}, 1)

		assert.is_true(r:is_valid_variable_row(1))
		assert.is_true(r:is_valid_variable_row(2))
		assert.is_true(r:is_valid_variable_row(3))

		assert.is_false(r:is_valid_variable_row(0))

		assert.is_false(r:is_valid_variable_row(4))
		assert.is_false(r:is_valid_variable_row(5))

		assert.is_false(r:is_valid_variable_row(10))
	end)

	it("local variables", function()
		local r = p.parse({
			"@a=b",
			"",
			"###",
			"",
			"@c=d",
			"@x=y",
			"",
			"GET http://host",
		}, 3)

		assert.is_true(r:is_valid_variable_row(4))
		assert.is_true(r:is_valid_variable_row(5))
		assert.is_true(r:is_valid_variable_row(6))
		assert.is_true(r:is_valid_variable_row(7))

		assert.is_false(r:is_valid_variable_row(1))
		assert.is_false(r:is_valid_variable_row(2))
		assert.is_false(r:is_valid_variable_row(3))

		assert.is_false(r:is_valid_variable_row(8))
	end)

	it("local variables invalid after headers", function()
		local r = p.parse({
			"###",
			"@c=d",
			"GET http://host",
			"Accept: application/json",
			"",
		}, 3)

		assert.is_true(r:is_valid_variable_row(2))

		assert.is_false(r:is_valid_variable_row(1))
		assert.is_false(r:is_valid_variable_row(3))
		assert.is_false(r:is_valid_variable_row(4))
		assert.is_false(r:is_valid_variable_row(5))
	end)
end)

describe("valid headers row:", function()
	it("no request", function()
		local r = p.parse({
			"",
		}, 1)

		assert.is_false(r:is_valid_headers_row(0))
		assert.is_false(r:is_valid_headers_row(1))
		assert.is_false(r:is_valid_headers_row(3))
	end)

	it("header after request", function()
		local r = p.parse({
			"GET http://host",
			"",
		}, 1)

		assert.is_true(r:is_valid_headers_row(2))

		assert.is_false(r:is_valid_headers_row(1))
	end)

	it("header after request, with existing headers", function()
		local r = p.parse({
			"GET http://host",
			"Accept: application/json",
			"",
		}, 1)

		assert.is_true(r:is_valid_headers_row(2))
		assert.is_true(r:is_valid_headers_row(3))

		assert.is_false(r:is_valid_headers_row(1))
	end)

	it("header before body", function()
		local r = p.parse({
			"GET http://host",
			"",
			"{}",
		}, 1)

		assert.is_true(r:is_valid_headers_row(2))

		assert.is_false(r:is_valid_headers_row(0))
		assert.is_false(r:is_valid_headers_row(1))
		assert.is_false(r:is_valid_headers_row(3))
	end)

	it("header before script", function()
		local r = p.parse({
			"GET http://host",
			"",
			"--{%",
			"--%}",
		}, 1)

		assert.is_true(r:is_valid_headers_row(2))

		assert.is_false(r:is_valid_headers_row(0))
		assert.is_false(r:is_valid_headers_row(1))
		assert.is_false(r:is_valid_headers_row(3))
	end)
end)

describe("valid url + query:", function()
	local function new(url, query)
		local r = result.new()
		r.request.url = url
		r.request.query = query
		return r
	end

	it("only url", function()
		local r = new("http://host"):url_with_query_string()
		assert.is_nil(r.request.query)
		assert.are.same("http://host", r.request.url)
	end)

	it("url with query-str, without query", function()
		local r = new("http://host?k=v"):url_with_query_string()
		assert.is_nil(r.request.query)
		assert.are.same("http://host?k=v", r.request.url)
	end)

	it("url with query-str two, without query", function()
		local r = new("http://host?k=v&k2=v2"):url_with_query_string()
		assert.is_nil(r.request.query)
		assert.are.same("http://host?k=v&k2=v2", r.request.url)
	end)

	it("url with query-str and with query", function()
		local r = new("http://host?k=v", { ["k2"] = "v2" }):url_with_query_string()
		assert.is_nil(r.request.query)
		assert.are.same("http://host?k=v&k2=v2", r.request.url)
	end)

	it("url without query-str, with query", function()
		local r = new("http://host", { k = "v" }):url_with_query_string()
		assert.are.same("http://host", r.request.url)
		assert.are.same({ k = "v" }, r.request.query)
	end)

	it("url query-str, with query and same key", function()
		local r = new("http://host?k=1", { k = "2" }):url_with_query_string()
		assert.is_nil(r.request.query)
		assert.are.same("http://host?k=1&k=2", r.request.url)
	end)

	it("url without query-str, with query, and always_append", function()
		local r = new("http://host", { k = "v" }):url_with_query_string(true)
		assert.are.same("http://host?k=v", r.request.url)
		assert.is_nil(r.request.query)
	end)

	it("with two query keys and values", function()
		local r = new("http://host", { k1 = "v1", k2 = "v2" }):url_with_query_string(true)
		local u1 = "http://host?k1=v1&k2=v2" == r.request.url
		local u2 = "http://host?k2=v2&k1=v1" == r.request.url
		-- print(r.request.url .. " " .. tostring(u1) .. " " .. tostring(u2) .. " " .. tostring(u1 or u2))
		assert.is_true((u1 or u2))
		assert.is_nil(r.request.query)
	end)
end)

describe("write to buffer", function()
	it("replace variable", function()
		local r = result.new()
		r.request.method = "GET"
		r.request.url = "http://host"
		r.request.query = {}
		r.replacements = { { from = "echo foo", to = "echo \n", type = "cmd" } }

		local bufnr = vim.api.nvim_create_buf(false, false)
		r:write_to_buffer(bufnr)

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
		assert.are.same("- 'echo foo': 'echo ' (cmd)", lines[10])
	end)
end)
