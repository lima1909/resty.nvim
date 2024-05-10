vim.api.nvim_create_user_command("Resty", function(opts)
	require("resty").run()
end, { nargs = "*" })
