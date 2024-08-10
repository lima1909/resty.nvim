local assert = require("luassert")
local parser = require("resty.parser")

describe("parse_line:", function()
	describe("variable", function()
		local kv = require("resty.parser.key_value")

		local p = parser.new()
		local result

		local set_result = function(_, r)
			result = r
		end

		it("nil, empty input", function()
			local r = p:parse_line(kv.parse_variable, "", set_result)
			assert.is_nil(r)
			assert.is_nil(result)
		end)

		it("nil, one not variable token char", function()
			local r = p:parse_line(kv.parse_variable, "x", set_result)
			assert.is_nil(r)
			assert.is_nil(result)
		end)

		it("nil, only variable token", function()
			local r = p:parse_line(kv.parse_variable, "@", set_result)
			assert.is_nil(r)
			assert.is_nil(result)
		end)

		it("true, no key", function()
			p = parser.new()
			local r = p:parse_line(kv.parse_variable, "@=value", set_result)
			assert.is_true(r)
			assert.is_nil(result)
			assert.are.same("an empty key is not allowed", p.errors[1].message)
		end)

		it("true, no value", function()
			p = parser.new()
			local r = p:parse_line(kv.parse_variable, "@key=", set_result)
			assert.is_true(r)
			assert.is_nil(result)
			assert.are.same("an empty value is not allowed", p.errors[1].message)
		end)

		it("true, valid", function()
			p = parser.new()
			local r = p:parse_line(kv.parse_variable, "@key=value", set_result)
			assert.is_true(r)
			assert.are.same(result, { k = "key", v = "value" })
		end)
	end)

	describe("method and url", function()
		local mu = require("resty.parser.method_url")

		local p = parser.new()
		local result

		local set_result = function(_, r)
			result = r
		end

		it("true, empty input", function()
			p = parser.new()
			local r = p:parse_line(mu.parse_method_url, "", set_result)
			assert.is_true(r)
			assert.is_nil(result)
			assert.are.same("expected two parts: method and url (e.g: 'GET http://foo'), got: ", p.errors[1].message)
		end)

		it("true, invalid method", function()
			p = parser.new()
			local r = p:parse_line(mu.parse_method_url, "GET_1 http://host", set_result)
			assert.is_true(r)
			assert.is_nil(result)
			assert.are.same("invalid method name: 'GET_1'. Only letters are allowed", p.errors[1].message)
		end)

		it("true, valid", function()
			p = parser.new()
			local r = p:parse_line(mu.parse_method_url, "get http://host", set_result)
			assert.is_true(r)
			assert.are.same(result, { method = "GET", url = "http://host" })
		end)
	end)

	describe("request body", function()
		local body = require("resty.parser.body")
		local body_parser = parser.STATE_BODY

		it("empty body", function()
			local p = parser.new()
			p:parse_line(body_parser.parser, body.request.open, body_parser.set_result)
			p:parse_line(body_parser.parser, body.request.close, body_parser.set_result)
			assert.is_true(p.body.is_ready)
			assert.are.same(p.request.body, "{\n}\n")
		end)
	end)

	describe("script body", function()
		local body = require("resty.parser.body")
		local script_parser = parser.STATE_SCRIPT

		it("empty body", function()
			local p = parser.new()
			p:parse_line(script_parser.parser, body.script.open, script_parser.set_result)
			p:parse_line(script_parser.parser, body.script.close, script_parser.set_result)
			assert.is_true(p.body.is_ready)
			assert.are.same(p.script, body.script.open .. "\n" .. body.script.close .. "\n")
		end)
	end)
end)
