local M = {}

-- definition of an request body
M.request = {
	open = "{",
	close = "}",
	len = 2,
}

-- definition of an script body
M.script = {
	open = "--{%",
	close = "--%}",
	len = 4,
}

local function is_body_start(line, body_type)
	if line:sub(1, body_type.len) == body_type.open then
		return true
	end
end

local function is_body_end(line, body_type)
	if line:sub(1, body_type.len) == body_type.close then
		return true
	end
end

local function parse_body(line, body_type, body)
	if body.is_ready or (not body.current_line and not is_body_start(line, body_type)) then
		return
	end

	if is_body_end(line, body_type) then
		body.is_ready = true
	end

	body.current_line = line

	return body
end

function M.parse_request_body(line, p)
	return parse_body(line, M.request, p.body)
end

function M.parse_script_body(line, p)
	return parse_body(line, M.script, p.body)
end

return M
