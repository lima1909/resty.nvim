local assert = require("luassert")
local p = require("resty.parser2")

describe("cut comments", function()
	it("# comment", function()
		local line = p.cut_comment("# comment")
		assert.are.same("", line)
	end)

	it("abc # comment", function()
		local line = p.cut_comment("abc # comment")
		assert.are.same("abc ", line)
	end)

	it("### comment", function()
		local line = p.cut_comment("### comment")
		assert.are.same("", line)
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
end)

describe("variables", function()
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
			local parser = p.new()
			local line = parser:replace_variable(variables, tc.input)
			if parser:has_errors() then
				assert.are.same(tc.err_msg, parser.errors[1].message)
			else
				assert.are.same(tc.expected, line)
			end
		end
	end)
end)

describe("ignore line", function()
	it("true", function()
		assert.is_true(p.ignore_line("#"))
		assert.is_true(p.ignore_line("# text"))
		assert.is_true(p.ignore_line(""))
		assert.is_true(p.ignore_line(" "))
	end)

	it("false", function()
		assert.is_false(p.ignore_line("###"))
		assert.is_false(p.ignore_line("@key=value"))
		assert.is_false(p.ignore_line("key=value"))
		assert.is_false(p.ignore_line("key:value"))
		assert.is_false(p.ignore_line("GET http://host"))
	end)
end)
