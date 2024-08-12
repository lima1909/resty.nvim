local M = {
	current_id = 0,
}

-- definition of an request body
M.request = {
	id = 1,
	open = "{",
	close = "}",
	len = 2,
}

-- definition of an script body
M.script = {
	id = 2,
	open = "--{%",
	close = "--%}",
	len = 4,
}

local function parse_body(line, body_type)
	-- parser has not started to parse the body
	if M.current_id ~= body_type.id then
		-- start
		if line:sub(1, body_type.len) == body_type.open then
			M.current_id = body_type.id
		else
			-- is not a valid body-type
			return
		end
	-- end
	elseif line:sub(1, body_type.len) == body_type.close then
		M.current_id = 0 -- reset the parser
	end

	return line
end

function M.parse_request_body(line)
	return parse_body(line, M.request)
end

function M.parse_script_body(line)
	return parse_body(line, M.script)
end

return M
