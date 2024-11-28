local resty = require("resty")
local cmd = require("resty.commands")
-- local util = require("resty.util")

vim.api.nvim_create_user_command("Resty", function(args)
	if args and #args.fargs > 0 then
		if args.fargs[1] == "run" then
			local input = args.args:sub(4) -- cut the 'run' command
			resty.run(input)
			return
		elseif args.fargs[1] == "favorite" then
			local sel_favorite = args.args:sub(9) -- cut the command
			sel_favorite = string.gsub(sel_favorite, "^%s+", "") -- cut the spaces
			resty.favorite(sel_favorite)
			return
		elseif args.fargs[1] == "debug" then
			resty.show_debug_info()
			return
		end
	end

	-- default call, if there are no arguments
	resty.last()
end, {
	nargs = "*", -- one or none argument
	range = true,
	desc = "Run a Resty requests",
	complete = cmd.complete,
})

-- no arg (or [last]) - call the last saved request
-- [run] - run the request where the cursor is located
-- [view] - show a list (with telescope) of possible request

-- fold expression definition for folding the individual rest calls
_G.foldexpr = function(lnum)
	local line = vim.fn.getline(lnum)

	if line:find("###") then
		return "0"
	end

	return "1"
end
