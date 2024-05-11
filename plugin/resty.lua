vim.api.nvim_create_user_command("Resty", function(args)
	if args and #args.fargs > 0 then
		print(vim.inspect(args))
		if args.fargs[1] == "run" then
			require("resty").run()
			return
		end

		require("resty").last()
	end
end, {
	nargs = "?", -- one or none argument
	desc = "Run a Resty requests",
	complete = function()
		return { "run", "view", "last" }
	end,
})

-- no arg (or [last]) - call the last saved request
-- [run] - run the request where the cursor is located
-- [view] - show a list (with telescope) of possible request
