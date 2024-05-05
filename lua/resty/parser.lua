---is a delimiter for a new starting rest call
local delimiter = "###"

---State-transitions: |init| -> |new| -> |call|
local state_init = 0
local state_new = 1
local state_call = 2

local parser = {}

---Parse the name after the start symbol '### [name]'
---@param line string
local function parse_name(line, nr)
	local name = string.sub(line, #delimiter + 1)
	name = vim.trim(name)

	-- if no name set
	if #name == 0 then
		name = "noname-" .. nr
	else
		-- replace whitespaces with underscore
		name = name:gsub("%s+", "_")
	end

	return name
end

---Parse the rest call (method + url)
---@param line string
local function parse_call(line)
	local parts = vim.split(line, " ")
	assert(#parts, 2, "expected two parts: method and url, got: " .. line)

	local method = parts[1]:upper()
	local url = parts[2]

	return method, url
end

---Entry point, the parser
---@param input string
parser.parse = function(input)
	local result = {}
	local lines = input or ""
	local name = ""
	local current_state = state_init

	for nr, line in ipairs(vim.split(lines, "\n")) do
		-- start parsing a new request
		if vim.startswith(line, delimiter) then
			current_state = state_new
			name = parse_name(line, nr)
			result[name] = { start_at = nr, header = {} }
			goto continue
		end

		if current_state == state_new then
			current_state = state_call
			local method, url = parse_call(line)
			result[name]["method"] = method
			result[name]["url"] = url
			goto continue
		end

		if current_state == state_call then
			-- set headers
			if line:find(":") then
				table.insert(result[name].header, vim.trim(line))
			end
		end

		::continue::
	end

	return result
end

return parser
