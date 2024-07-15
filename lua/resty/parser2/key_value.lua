-- Parser for key-value pairs:
--  - variable:	@key=value
--  - headers:	key:value
--  - query:	key=value
--
local M = {}

local function split_key_value(line, delimiter, pos)
	local key = line:sub(1, pos - #delimiter)
	key = vim.trim(key)
	local value = line:sub(pos + #delimiter)
	value = vim.trim(value)

	if #key == 0 then
		error("an empty key is not allowed", 0)
	end

	if #value == 0 then
		error("an empty value is not allowed", 0)
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

function M.parse_variable(line)
	if not vim.startswith(line, token_VARIABLE) then
		return nil
	end

	-- cut the variable token
	local l = string.sub(line, #token_VARIABLE + 1)
	local pos_eq = l:find("=")

	local k, v = split_key_value(l, "=", pos_eq)

	return {
		k = k,
		v = v,
	}
end

function M.parse_headers_query(line)
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

	local k, v = split_key_value(line, delimiter, pos)

	return {
		k = k,
		v = v,
		delimiter = delimiter,
	}
end

return M
