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
	self.state = state_ready

	local pos_space = line:find(" ")

	if not pos_space then
		return error("expected two parts: method and url (e.g: 'GET http://foo'), got: " .. line)
	end

	local method = vim.trim(line:sub(1, pos_space - 1)):upper()
	local url = vim.trim(line:sub(pos_space + 1, #line))
	return method, url
end

local function parse_key_value(line, pos_eq)
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

	local p = new_parser()
	local result = {}

	for nr, line in ipairs(lines) do
		-- parse the end of request
		if vim.startswith(line, end_token) then
			break
		-- start parsing a new request and parse the name
		elseif vim.startswith(line, start_token) then
			local name = p:parse_name(line, nr)
			table.insert(result, req_def.new(name, nr))
		-- parse method and url
		elseif p.state == state_started then
			result[#result]:set_method_url(p:parse_method_url(line))
		-- parse query and headers
		elseif p.state == state_ready then
			local pos_eq = line:find("=")
			local pos_dp = line:find(":")

			-- contains both, = and :
			if pos_eq ~= nil and pos_dp ~= nil then
				-- the first finding wins
				if pos_eq < pos_dp then
					-- set query
					result[#result]:query(parse_key_value(line, pos_eq))
				else
					-- set headers
					result[#result]:headers(parse_key_value(line, pos_dp))
				end
			elseif pos_eq ~= nil then
				-- set query
				result[#result]:query(parse_key_value(line, pos_eq))
			elseif pos_dp ~= nil then
				-- set headers
				result[#result]:headers(parse_key_value(line, pos_dp))
			end
		end

		if result[#result] then
			result[#result].end_at = nr
		end
	end

	return result
end

return M
