local req_def = {}
req_def.__index = req_def

---create a new request definition instance
---@param name string
---@param start_at integer
---@return table
local function new_req_def(name, start_at)
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

local M = {}
M.__index = M

function M.new_req_def_list()
	local list = { definitions = {} }
	return setmetatable(list, M)
end

function M:add_variables(name, value)
	if not self.variables then
		self.variables = {}
	end
	self.variables[name] = value
end

function M:current_req_def()
	return self.definitions[#self.definitions]
end

function M:add_req_def(name, nr)
	table.insert(self.definitions, new_req_def(name, nr))
end

function M:set_method_url(method, url)
	self:current_req_def():set_method_url(method, url)
end

function M:query(key, value)
	self:current_req_def():query(key, value)
end

function M:headers(key, value)
	self:current_req_def():headers(key, value)
end

function M:set_end_line_nr(line_nr)
	if self:current_req_def() then
		self:current_req_def().end_at = line_nr
	end
end

function M.replace_variable(variables, property)
	if not variables then
		return property
	end

	local _, start_pos = string.find(property, "{{")
	if not start_pos then
		return property
	end

	local end_pos, _ = string.find(property, "}}")
	if not end_pos then
		return property
	end

	local before = string.sub(property, 1, start_pos - 2)
	local name = string.sub(property, start_pos + 1, end_pos - 1)
	local after = string.sub(property, end_pos + 2)

	name = variables[name]
	if not name then
		return property
	end

	return before .. name .. after
end

-- function M.replace_variable(variables)
-- for key, value in pairs(variables) do
-- end
-- end

function M:get_req_def_by_row(row)
	for _, d in pairs(self.definitions) do
		if d.start_at <= row and d.end_at >= row then
			d.req.url = M.replace_variable(self.variables, d.req.url)
			return d
		end
	end

	return nil
end

return M
