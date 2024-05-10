local req_def = require("resty.request")

---is a start_token for a new starting rest call
local start_token = "###"
---end_token is optional, is it necessary if the buffer contains more rows
---otherwise is the end of the buffer the end of parsing
local end_token = "---"

---State-transitions: |init| -> |new| -> |call|
local state_init = 0
local state_started = 1
local state_ready = 2

local parser = {}
parser.__index = parser

local function new_parser()
	local p = { state = state_init }
	return setmetatable(p, parser)
end

---Parse the name after the start symbol '### [name]'
---@param line string
---@param nr integer
function parser:parse_name(line, nr)
	self.state = state_started

	local name = string.sub(line, #start_token + 1)
	name = vim.trim(name)
	-- if no name set
	if #name == 0 then
		name = "noname_" .. nr
	else
		-- replace whitespaces with underscore
		name = name:gsub("%s+", "_")
	end
	return name
end

---Parse the rest call (method + url)
---@param line string
function parser:parse_method_url(line)
	local parts = vim.split(line, " ")
	if #parts < 2 then
		return error("expected two parts: method and url (e.g: 'GET http://foo'), got: " .. line)
	end

	self.state = state_ready

	local method = vim.trim(parts[1]:upper())
	local url = vim.trim(parts[2])
	return method, url
end

local function parse_headers(line)
	local parts = vim.split(line, ":")
	assert(#parts, 2, "expected two parts: header-key and value, got: " .. line)
	local key = parts[1]
	local value = vim.trim(parts[2])
	return key, value
end

local function parse_query(line, pos_eq)
	local key = vim.trim(line:sub(1, pos_eq - 1))
	local value = vim.trim(line:sub(pos_eq + 1, #line))
	return key, value
end

local M = {}

---Entry point, the parser
---@param input string | { }
M.parse = function(input)
	local lines
	if type(input) == "string" then
		lines = vim.split(input, "\n")
	elseif type(input) == "table" then
		lines = input
	end

	local result = {}
	local name = ""
	local p = new_parser()

	for nr, line in ipairs(lines) do
		-- parse the end of request
		if vim.startswith(line, end_token) then
			break
		-- start parsing a new request and parse the name
		elseif vim.startswith(line, start_token) then
			name = p:parse_name(line, nr)
			result[name] = req_def.new(name, nr)
		-- parse method and url
		elseif p.state == state_started then
			result[name]:set_method_url(p:parse_method_url(line))
		-- parse query and headers
		elseif p.state == state_ready then
			local pos_eq = line:find("=")
			-- set query
			if pos_eq then
				result[name]:query(parse_query(line, pos_eq))
			-- set headers
			elseif line:find(":") then
				result[name]:headers(parse_headers(line))
			end
		end

		if result[name] then
			result[name].end_at = nr
		end
	end

	return result
end

return M
