local assert = require("luassert")
local statuscode = require("resty.output.statuscode")

describe("statuscode:", function()
	it("200", function()
		assert.are.same({ is_ok = true, text = "OK", code = 200 }, statuscode.get_status_def(200))
	end)

	it("201", function()
		assert.are.same({ is_ok = true, text = "Created", code = 201 }, statuscode.get_status_def(201))
	end)

	it("403", function()
		assert.are.same({ text = "Forbidden", code = 403 }, statuscode.get_status_def(403))
	end)

	it("invalid 999", function()
		assert.are.same({ code = 999, text = "invalid status code" }, statuscode.get_status_def(999))
	end)
end)
