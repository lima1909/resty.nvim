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

		assert.are.same(2, #entries)
		assert.are.same("connection: keep-alive", entries[1].label)
		assert.are.same("content-length: ", entries[2].label)
	end)
end)

describe("resty-cmp:", function()
	it("add global variable host", function()
		local entries = cmp.get_varcfg_entries({
			"@host = http://host",
			"###",
			"GET http://{{host}}",
		}, 3, { raw = "", dry_run = "", proxy = "", check_json_body = "" })

		assert.are.same(3, #entries)
		assert.are.same("insecure", entries[1].label)
		assert.are.same("timeout", entries[2].label)
		assert.are.same("host", entries[3].label)
	end)

	it("no new global variable", function()
		local vars = { raw = "", dry_run = "", proxy = "", check_json_body = "", host = "http://fo" }
		local entries = cmp.get_varcfg_entries({
			"@host = http://host",
			"###",
			"GET http://{{host}}",
		}, 3, vars)

		assert.are.same(2, #entries)
		assert.are.same("insecure", entries[1].label)
		assert.are.same("timeout", entries[2].label)
	end)

	it("add global variable host", function()
		local vars = { raw = "", dry_run = "", proxy = "", check_json_body = "", port = "8765" }
		local entries = cmp.get_varcfg_entries({
			"@host = http://host",
			"@port = 1234",
			"###",
			"GET http://{{host}}",
		}, 3, vars)

		assert.are.same(3, #entries)
		assert.are.same("insecure", entries[1].label)
		assert.are.same("timeout", entries[2].label)
		assert.are.same("host", entries[3].label)
	end)

	it("entries for variables and request", function()
		local entries = cmp.entries({
			"###",
			"@host = http://host",
			"@port = 1234",
			"",
			"@raw = --insecure",
			"@dry_run = try",
			"@proxy = http://host",
			"@check_json_body = true",
			"",
			"",
		}, "", 9)

		assert.are.same(6, #entries)
		assert.are.same("insecure", entries[1].label)
		assert.are.same("timeout", entries[2].label)
		assert.are.same("GET http://", entries[3].label)
		assert.are.same("GET https://", entries[4].label)
		assert.are.same("POST http://", entries[5].label)
		assert.are.same("POST https://", entries[6].label)
	end)
end)
