local M = {}

---is a token_start for a new starting rest call
local token_DELIMITER = "###"

local function find_delimiter(lines, selected, step)
	local with_delimiter = false

	while true do
		local line = lines[selected]
		if not line then
			selected = selected + (step * -1)
			break
		elseif vim.startswith(line, token_DELIMITER) then
			selected = selected + (step * -1)
			with_delimiter = true
			break
		end
		selected = selected + step
	end

	return with_delimiter, selected
end

function M.find_request(lines, selected)
	local result = {}
	result.sw_delim, result.s = find_delimiter(lines, selected, -1)

	selected = selected + 1
	result.ew_delim, result.e = find_delimiter(lines, selected, 1)

	return result
end

function M.find_req_def(lines, selected)
	local start_req_def = selected

	while true do
		local line = lines[start_req_def]
		if not line then
			start_req_def = start_req_def + 1
			break
		elseif vim.startswith(line, token_DELIMITER) then
			break
		end
		start_req_def = start_req_def - 1
	end

	local end_req_def = selected + 1
	while true do
		local line = lines[end_req_def]
		if not line or vim.startswith(line, token_DELIMITER) then
			end_req_def = end_req_def - 1
			break
		end
		end_req_def = end_req_def + 1
	end

	return start_req_def, end_req_def
end

M.parse_delimiter = function(p, line)
	if not vim.startswith(line, token_DELIMITER) then
		return nil
	end

	if p.readed_lines > p.selected then
		p:add_error("the selected row: " .. p.selected .. " is not in a request definition")
		return true
	end

	p.readed_lines, p.end_line = M.find_req_def(p.lines, p.selected)

	return true
end

return M
