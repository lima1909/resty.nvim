---is a token_start for a new starting rest call
local token_START = "###"
---token_end is optional, is it necessary if the buffer contains more rows
---otherwise is the end of the buffer the end of parsing
local token_END = "---"
---is the token for comments
local token_COMMENT = "#"

---is the token for defining a variable
local token_VARIABLE = "@"

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

local function parse_key_value(line, pos_eq)
	local key = vim.trim(line:sub(1, pos_eq - 1))
	local value = vim.trim(line:sub(pos_eq + 1, #line))
	return key, value
end

---Parse the given variable
---Example: @hostname = api.example.com
---@param line string
function parser:parse_variable(line)
	local l = string.sub(line, #token_VARIABLE + 1)
	local pos_eq = l:find("=")
	return parse_key_value(l, pos_eq)
end

---Parse the name after the start symbol '### [name]'
---@param line string
---@param nr integer
function parser:parse_name(line, nr)
	self.state = state_started

	local name = string.sub(line, #token_END + 1)
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

	local list = require("resty.request").new_req_def_list()
	local p = new_parser()

	for nr, line in ipairs(lines) do
		-- parse the END of request
		if vim.startswith(line, token_END) then
			break
		-- find a VARIABLE definition
		elseif vim.startswith(line, token_VARIABLE) then
			list:add_variables(p:parse_variable(line))
		-- START parsing a new request and parse the name
		elseif vim.startswith(line, token_START) then
			local name = p:parse_name(line, nr)
			list:add_req_def(name, nr)
		--  COMMENTS
		elseif vim.startswith(line, token_COMMENT) then
			goto continue
		-- parse METHOD and URL
		elseif p.state == state_started then
			list:set_method_url(p:parse_method_url(line))
		-- parse QUERY and HEADERS
		elseif p.state == state_ready then
			local pos_eq = line:find("=")
			local pos_dp = line:find(":")

			-- contains both, = and :
			if pos_eq ~= nil and pos_dp ~= nil then
				-- the first finding wins
				if pos_eq < pos_dp then
					-- set query
					list:query(parse_key_value(line, pos_eq))
				else
					-- set headers
					list:headers(parse_key_value(line, pos_dp))
				end
			elseif pos_eq ~= nil then
				-- set query
				list:query(parse_key_value(line, pos_eq))
			elseif pos_dp ~= nil then
				-- set headers
				list:headers(parse_key_value(line, pos_dp))
			end
		end

		list:set_end_line_nr(nr)

		::continue::
	end

	return list
end

return M
