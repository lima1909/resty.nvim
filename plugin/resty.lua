vim.api.nvim_create_user_command("Resty", function(opts)
	local resty = require("resty")
	resty.run()
end, { nargs = "*" })
