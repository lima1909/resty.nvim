local M = {}

local request = {
	open = "{",
	close = "}",
	len = 2,
}

local script = {
	open = "--{",
	close = "}--",
	len = 4,
}

local function is_body_start(line, b)
	if line:sub(1, b.len) == b.open then
		return true
	end
end

local function is_body_end(line, b)
	if line:sub(1, b.len) == b.close then
		return true
	end
end

local function parse_body(line, p, b)
	if p.body_is_ready or (not p.request.body and not is_body_start(line, b)) then
		return
	end

	local is_ready = false
	if is_body_end(line, b) then
		is_ready = true
	end

	return { is_ready = is_ready, line = line .. "\n" }
end

function M.parse_request_body(line, p)
	return parse_body(line, p, request)
end

function M.parse_script_body(line, p)
	return parse_body(line, p, script)
end

return M
