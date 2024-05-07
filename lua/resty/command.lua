local buf_content_lines = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), true)
	--[[ 
	
### first test
Get https://httpbin.org/get 

accept: application/json  
Authorization: Bearer mytoken123

filter = id = 42 and age > 42
include = sub, *   
---

]]
	return lines
end

---
package.loaded["resty.parser"] = nil
local p = require("resty.parser")

local r = p.parse(buf_content_lines())
local req = r.first_test

-- print(vim.inspect(req))

local assert = require("luassert")

--[[ assert.are.same(req, {
	start_at = 5,
	end_at = 7,
	method = "GET",
	url = "https://httpbin.org/get",
	headers = {},
	query = {},
}) ]]

local curl = require("plenary.curl")

local result = curl.request(req)
assert.are.same(200, result.status)

-- print(vim.inspect(result))
