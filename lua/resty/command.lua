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
local def = r.first_test

local assert = require("luassert")
local curl = require("plenary.curl")

local response = curl.request(def.req)
assert.are.same(200, response.status)

print(vim.inspect(response))
