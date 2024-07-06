local M = {}

M.STATE_METHOD_URL = 4

function M.parse_method_url(p, line)
	local pos_space = line:find(" ")
	if not pos_space then
		return p:add_error("expected two parts: method and url (e.g: 'GET http://foo'), got: " .. line)
	end

	local method = vim.trim(line:sub(1, pos_space - 1))
	if not method:match("^[%aZ]+$") then
		return p:add_error("invalid method name: '" .. method .. "'. Only letters are allowed")
	end

	p.current_state = M.STATE_METHOD_URL
	p.request = {
		method = method:upper(),
		url = vim.trim(line:sub(pos_space + 1, #line)),
	}

	return true
end

return M
