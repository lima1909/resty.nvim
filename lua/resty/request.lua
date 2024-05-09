local req_def = {}
req_def.__index = req_def

---create a new request definition instance
---@param name string
---@param start_at integer
---@return table
function req_def.new(name, start_at)
	local rd = {
		start_at = start_at,
		end_at = start_at,
		name = name,
		req = {
			headers = {},
			query = {},
		},
	}
	return setmetatable(rd, req_def)
end

---set request method and url
---@param method string
---@param url string
function req_def:set_method_url(method, url)
	self.req.method = method
	self.req.url = url
end

---add header: key and value
---@param key string
---@param value string
function req_def:headers(key, value)
	self.req.headers[key] = value
end
--
---add query-parameter: key and value
---@param key string
---@param value string
function req_def:query(key, value)
	self.req.query[key] = value
end

return req_def
