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
			["Accept"] = "",
			["Authorization"] = "",
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

describe("resty-cmp:", function()
	local request = { raw = "", dry_run = "", proxy = "", check_json_body = "" }

	it("add global variable host", function()
		local entries = cmp.get_varcfg_entries({
			"@host = http://host",
			"###",
			"GET http://{{host}}",
		}, 3, request, {})

		assert.are.same(3, #entries)
		assert.are.same("insecure", entries[1].label)
		assert.are.same("timeout", entries[2].label)
		assert.are.same("host", entries[3].label)
	end)

	it("no new global variable", function()
		local entries = cmp.get_varcfg_entries({
			"@host = http://host",
			"###",
			"GET http://{{host}}",
		}, 3, request, { host = "http://fo" })

		assert.are.same(2, #entries)
		assert.are.same("insecure", entries[1].label)
		assert.are.same("timeout", entries[2].label)
	end)

	it("add global variable host", function()
		local entries = cmp.get_varcfg_entries({
			"@host = http://host",
			"@port = 1234",
			"###",
			"GET http://{{host}}",
		}, 3, request, { port = "8765" })

		assert.are.same(3, #entries)
		assert.are.same("insecure", entries[1].label)
		assert.are.same("timeout", entries[2].label)
		assert.are.same("host", entries[3].label)
	end)
end)
