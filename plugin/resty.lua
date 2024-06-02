vim.api.nvim_create_user_command("Resty", function(args)
	if args and #args.fargs > 0 then
		if args.fargs[1] == "run" then
			require("resty").run()
			return
		elseif args.fargs[1] == "diagnostic" then
			require("resty").diagnostic()
			return
		end
	end

	-- default call, if there are no arguments
	require("resty").last()
end, {
	nargs = "?", -- one or none argument
	desc = "Run a Resty requests",
	complete = function()
		return { "diagnostic", "last", "run" }
	end,
})

-- no arg (or [last]) - call the last saved request
-- [run] - run the request where the cursor is located
-- [view] - show a list (with telescope) of possible request
