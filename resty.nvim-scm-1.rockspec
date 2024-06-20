local MODREV, SPECREV = "scm", "-1"
rockspec_format = "3.0"
package = "resty.nvim"
version = MODREV .. SPECREV

description = {
	homepage = "https://github.com/lima1909/resty.nvim",
	labels = { "neovim" },
	license = "MIT",
}

dependencies = {
	"lua == 5.1",
	"plenary.nvim",
	"luassert",
}

source = {
	url = "git://github.com/lima1909/resty.nvim",
}

build = {
	type = "builtin",
	copy_directories = {
		"ftdetect",
		"plugin",
	},
	modules = {
		["resty"] = "lua/resty/init.lua",
	},
}
