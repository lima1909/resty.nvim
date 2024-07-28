local M = {}

local function is_body_start(line)
	if line:sub(1, 2) == "{" then
		return true
	end
end

local function is_body_end(line)
	if line:sub(1, 2) == "}" then
		return true
	end
end

function M.parse_body(line, p)
	if p.body_is_ready then
		return
	end

	if not p.request.body then
		if is_body_start(line) then
			p.request.body = line .. "\n"
		else
			return
		end
	elseif is_body_end(line) then
		p.request.body = p.request.body .. line .. "\n"
		p.body_is_ready = true
	else
		p.request.body = p.request.body .. line .. "\n"
	end

	return true
end

return M
