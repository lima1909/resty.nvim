vim.api.nvim_create_user_command("Resty", function(opts)
	local response = require("resty").run()
	print(vim.inspect(response))
end, { nargs = "*" })
