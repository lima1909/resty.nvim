local M = {}

M.duration = function(time)
	if not time then
		return "no time avialable"
	end

	local units = { "s", "ms", "µs", "ns" }
	local current_unit_pos = 1

	while time < 1 and current_unit_pos <= #units do
		time = time * 1000
		current_unit_pos = current_unit_pos + 1
	end

	return string.format("%.2f %s", time, units[current_unit_pos])
end

--[[
{ "-sSL", "-D", "/run/user/1000/plenary_curl_40ad4fc7.headers", 
  "--compressed", "-X", "GET", "-H", "Accept: application/json", "-H", "Cache-Control: no-cache", 
  "https://jsonplaceholder.typicode.com/comments?id=5" 
}

-sSL: Silent mode (no progress meter) and follow redirects.
-D headers.txt https://example.com will save the headers to headers.txt
-D - https://example.com will output the headers directly to the terminal or standard output

-X GET: Specifies the HTTP method (in this case, GET).
-H Adds a header to the request.


--]]

M.curl = function(cmd)
	local len = #cmd
	local result = {}
	local not_next = false

	for i = 1, len do
		local v = cmd[i]

		if not_next == false then
			if i == len then
				result.url = cmd[i]
			elseif v == "-X" then
				not_next = true
				result.method = cmd[i + 1]
			elseif v == "-D" then
				not_next = true
				result.resoponse_headers_file = cmd[i + 1]
			elseif v == "-H" then
				result.headers = result.headers or {}
				not_next = true
				table.insert(result.headers, cmd[i + 1])
			else
				result.args = result.args or {}
				table.insert(result.args, cmd[i])
			end
		else
			not_next = false
		end
	end

	return result
end

return M
