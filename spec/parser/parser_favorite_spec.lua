local assert = require("luassert")
local f = require("resty.parser.favorite")

describe("favorite:", function()
	local input = [[

### #first
GET http://host.com

### no favorite, only comment
GET http://host.com

### 
GET http://host.com

### # next one
GET http://host.com

###    #next one one
GET http://host.com
]]

	describe("favorite one:", function()
		it("find first", function()
			local row = f.find_favorite(input, "first")
			assert.are.same(2, row)
		end)

		it("find next one", function()
			local row = f.find_favorite(input, " next one")
			assert.are.same(11, row)
		end)

		it("not found", function()
			local row = f.find_favorite(input, "not found")
			assert.is_nil(row)
		end)
	end)

	describe("favorite all:", function()
		it("find all", function()
			local rows = f.find_all_favorites(input)
			assert.are.same({
				{ ["row"] = 2, ["favorite"] = "first" },
				{ ["row"] = 11, ["favorite"] = " next one" },
				{ ["row"] = 14, ["favorite"] = "next one one" },
			}, rows)
		end)
	end)
end)
