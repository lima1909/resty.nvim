local M = {}

function M.parse_method_url(line)
	line = string.gsub(line, "^%s+", "") -- trim the spaces in the start

	local pos_space = line:find(" ")
	if not pos_space then
		error("expected two parts: method and url (e.g: 'GET http://foo'), got: " .. line, 0)
	end

	local method = vim.trim(line:sub(1, pos_space - 1))
	if not method:match("^[%aZ]+$") then
		error("invalid method name: '" .. method .. "'. Only letters are allowed", 0)
	end

	return {
		method = method:upper(),
		url = vim.trim(line:sub(pos_space + 1, #line)),
	}
end

return M
