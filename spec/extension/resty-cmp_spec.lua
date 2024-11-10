local assert = require("luassert")
local cmp = require("resty.extension.resty-cmp")
local items = require("resty.extension.resty-cmp-items")

describe("resty-cmp-items:", function()
	it("available varcfg", function()
		local entries = items.available_varcfg({
			raw = "",
			dry_run = "",
			proxy = "",
			check_json_body = "",
		})

		assert.are.same(2, #entries)
		assert.are.same("insecure", entries[1].label)
		assert.are.same("timeout", entries[2].label)
	end)

	it("available headers", function()
		local entries = items.available_headers({
			Accept = "",
			Authorization = "",
			["Accept-Charset"] = "",
			["Content-Type"] = "",
			["Cache-Control"] = "",
			["Accept-Encoding"] = "",
		})

		-- print(vim.inspect(entries))

		assert.are.same(2, #entries)
		assert.are.same("connection: keep-alive", entries[1].label)
		assert.are.same("content-length: ", entries[2].label)
	end)
end)
