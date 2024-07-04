-- Parser for key-value pairs:
--  - variable:	@key=value
--  - headers:	key:value
--  - query:	key=value
--
local M = {}

M.STATE_VARIABLE = 2
M.STATE_HEADERS_QUERY = 5

local function split_key_value(p, line, delimiter, pos)
	local key = line:sub(1, pos - #delimiter)
	key = vim.trim(key)
	local value = line:sub(pos + #delimiter)
	value = vim.trim(value)

	if #key == 0 then
		p:add_error("an empty key is not allowed")
		return
	end

	if #value == 0 then
		p:add_error("an empty value is not allowed")
		return
	end

	-- CHECK duplicate
	-- if map[key] then
	-- self:add_error(line_nr, "the key: '" .. key .. "' already exist")
	-- return
	-- end

	return key, value
end

---is the token for defining a variable
local token_VARIABLE = "@"

function M.parse_variable(p, line)
	if not vim.startswith(line, token_VARIABLE) then
		return nil
	end

	-- cut the variable token
	local l = string.sub(line, #token_VARIABLE + 1)
	local pos_eq = l:find("=")
	local k, v = split_key_value(p, l, "=", pos_eq)
	if k then
		p.global_variables[k] = v
	end

	p.current_state = M.STATE_VARIABLE
	return true
end

function M.parse_headers_query(p, line)
	local pos_eq = line:find("=")
	local pos_dp = line:find(":")

	if pos_eq == nil and pos_dp == nil then
		-- is not a query, not header
		-- error("is not a query or a header definition: "..line)
		return nil, nil
	end

	local pos, delimiter

	-- contains both, = and :
	if pos_eq ~= nil and pos_dp ~= nil then
		-- the first finding wins
		if pos_eq < pos_dp then
			-- set query
			delimiter, pos = "=", pos_eq
		else
			-- set headers
			delimiter, pos = ":", pos_dp
		end
	elseif pos_eq ~= nil then
		-- set query
		delimiter, pos = "=", pos_eq
	elseif pos_dp ~= nil then
		-- set headers
		delimiter, pos = ":", pos_dp
	end

	local k, v = split_key_value(p, line, delimiter, pos)
	if not k then
		return
	end

	p.current_state = M.STATE_HEADERS_QUERY
	p.request.headers = p.request.headers or {}
	p.request.query = p.request.query or {}

	if delimiter == "=" then
		p.request.query[k] = v
	else
		p.request.headers[k] = v
	end

	return true
end

return M
