local exec = require("resty.exec")

local M = {}

M.TypeVar = {
	symbol = "",
	text = "variable",
}

M.TypeEnv = {
	symbol = "$",
	text = "environment",
}

M.TypeCmd = {

	symbol = ">",
	text = "commmand",
}

M.TypePrompt = {
	symbol = ":",
	text = "prompt",
}

function M.execute(key)
	local symbol = key:sub(1, 1)

	-- environment variable
	if symbol == M.TypeEnv.symbol then
		return os.getenv(key:sub(2):upper()), true, M.TypeEnv
	-- commmand
	elseif symbol == M.TypeCmd.symbol then
		return exec.cmd(key:sub(2)), true, M.TypeCmd
	-- prompt
	elseif symbol == M.TypePrompt.symbol then
		return vim.fn.input("Input for key " .. key:sub(2) .. ": "), true, M.TypePrompt
	else
		return key, false, M.TypeVar
	end
end

local function _replace_variable(variables, line, replaced)
	local _, start_pos = string.find(line, "{{")
	local end_pos, _ = string.find(line, "}}")

	if not start_pos and not end_pos then
		-- no variable found
		return line
	elseif start_pos and not end_pos then
		error("missing closing brackets: '}}'", 0)
	elseif not start_pos and end_pos then
		error("missing open brackets: '{{'", 0)
	end

	local before = string.sub(line, 1, start_pos - 2)
	local name = string.sub(line, start_pos + 1, end_pos - 1)
	local after = string.sub(line, end_pos + 2)

	local value, ok, type = M.execute(name)
	if ok == false then
		value = variables[name]
		if not value then
			error("no variable found with name: '" .. name .. "'", 0)
		end
		value, ok, type = M.execute(value)
	end

	table.insert(replaced, { from = name, to = value, type = type })
	local new_line = before .. value .. after
	return _replace_variable(variables, new_line, replaced)
end

function M.replace_variable(variables, line)
	local replaced = {}
	return _replace_variable(variables, line, replaced), replaced
end

return M
