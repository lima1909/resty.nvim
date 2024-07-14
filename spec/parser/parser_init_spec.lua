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
		assert.are.same("### comment", line)
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
			local line, err = p.replace_variable(variables, tc.input)
			if err then
				assert.are.same(tc.err_msg, err)
			else
				assert.are.same(tc.expected, line)
			end
		end
	end)
end)
