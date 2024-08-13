local assert = require("luassert")
local p = require("resty.parser")

local do_nothing_parser = function()
	return nil
end

describe("cut comments", function()
	it("# comment", function()
		local r = p.new():read_line("# comment", do_nothing_parser)
		assert.is_false(r)
	end)

	it("abc # comment", function()
		local line
		local r = p.new():read_line("abc # comment", function(_, l)
			line = l
		end)
		assert.is_true(r)
		assert.are.same("abc ", line)
	end)

	it("### comment", function()
		local r = p.new():read_line("### comment", do_nothing_parser)
		assert.is_false(r)
	end)

	it("comment in line", function()
		local tt = {
			{ input = "host ", expected = "host " },
			{ input = "host # comment", expected = "host " },
			{ input = "host# comment", expected = "host" },
			{ input = "host#", expected = "host" },
		}
		for _, tc in ipairs(tt) do
			local line
			local r = p.new():read_line(tc.input, function(_, l)
				line = l
			end)

			assert.is_true(r)
			assert.are.same(tc.expected, line)
		end
	end)
end)

describe("variables", function()
	it("replace variable", function()
		local v = require("resty.parser.variables")
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
			-- environment variable
			{ input = "{{$user}}", expected = os.getenv("USER") },
			-- shell command
			{ input = "{{> echo 'my value'}}", expected = "my value\n" },
		}

		for _, tc in ipairs(tt) do
			local parser = p.new()
			local line = parser:replace_variable(variables, tc.input, {})
			if parser:has_errors() then
				assert.are.same(tc.err_msg, parser.errors[1].message)
			else
				assert.are.same(tc.expected, line)
			end
		end
	end)
end)
--
describe("ignore line", function()
	it("true", function()
		assert.is_false(p.new():read_line("#", do_nothing_parser))
		assert.is_false(p.new():read_line("# text", do_nothing_parser))
		assert.is_false(p.new():read_line("", do_nothing_parser))
		assert.is_false(p.new():read_line(" ", do_nothing_parser))
	end)

	it("false", function()
		assert.is_false(p.new():read_line("###", do_nothing_parser))
		assert.is_false(p.new():read_line("{{foo", do_nothing_parser))
	end)

	it("nil", function()
		assert.is_true(p.new():read_line("@key=value", do_nothing_parser))
		assert.is_true(p.new():read_line("key=value", do_nothing_parser))
		assert.is_true(p.new():read_line("key:value", do_nothing_parser))
		assert.is_true(p.new():read_line("GET http://host", do_nothing_parser))
	end)
end)
