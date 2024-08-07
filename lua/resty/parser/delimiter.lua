local M = {}

---is a token_start for a new starting rest call
local token_DELIMITER = "###"

local function find_delimiter(lines, selected, step)
	while true do
		local line = lines[selected]
		if not line or vim.startswith(line, token_DELIMITER) then
			break
		end
		selected = selected + step
	end

	return selected + step * -1
end

function M.find_request(lines, selected)
	local len = #lines
	if selected > len then
		error("the selected row: " .. selected .. " is greater then the given rows: " .. len, 0)
	elseif selected == len and vim.startswith(lines[len], token_DELIMITER) then
		error("after the selected row: " .. selected .. " are no more input lines", 0)
	end

	local s = find_delimiter(lines, selected, -1)
	local e = find_delimiter(lines, selected + 1, 1)

	if s > e then
		error("after the selected row: " .. selected .. " are no more input lines", 0)
	end

	return s, e
end

return M
