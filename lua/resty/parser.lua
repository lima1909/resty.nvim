local delimiter = "###"

local parser = {}

---Parse the name after the start symbol '### [name]'
---@param line string
local function parse_name(line)
	local name = string.sub(line, #delimiter + 1)
	name = vim.trim(name)
	-- replace whitespaces with underscore
	name = name:gsub("%s+", "_")

	return name
end

---Parse the rest call (method + url)
---@param line string
local function parse_rest_call(line)
	local parts = vim.split(line, " ")
	assert(#parts, 2, "expected two parts: method and url, got: " .. line)

	local method = parts[1]:upper()

	return method, parts[2]
end

---Entry point, the parser
---@param input string
parser.parse = function(input)
	local result = {}
	local lines = input or ""
	local name = ""

	for nr, line in ipairs(vim.split(lines, "\n")) do
		if vim.startswith(line, delimiter) then
			name = parse_name(line)
			result[name] = { start_at = nr }
		else
			local method, url = parse_rest_call(line)
			local current = result[name]
			current["method"] = method
			current["url"] = url
		end

		-- print(nr, line)
	end

	return result
end

return parser
