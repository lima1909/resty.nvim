local favorite = require("resty.extension.favorites")

local M = {}

M.CMD_RUN = "run"
M.CMD_LAST = "last"
M.CMD_FAVORITE = "favorite"

M.COMMANDS = { M.CMD_FAVORITE, M.CMD_LAST, M.CMD_RUN }

M.complete_cmd = function(arglead)
	if vim.trim(arglead):len() == 0 then
		return M.COMMANDS
	end

	local cmds = {}
	for _, cmd in ipairs(M.COMMANDS) do
		if vim.startswith(cmd, arglead) then
			table.insert(cmds, cmd)
		end
	end

	if #cmds ~= 0 then
		return cmds
	end

	return M.COMMANDS
end

M.complete = function(arglead, cmdline)
	if cmdline == "Resty " .. M.CMD_RUN or cmdline == "Resty " .. M.CMD_LAST then
		return {}
	elseif vim.startswith(cmdline, "Resty " .. M.CMD_FAVORITE) then
		local bufnr = favorite.get_current_bufnr()
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
		return favorite.find_favorite_by_prefix(lines, arglead)
	else
		return M.complete_cmd(arglead)
	end
end

return M
