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
		["resty.exec"] = "lua/resty/exec.lua",
		["resty.parser"] = "lua/resty/parster.lua",
		["resty.output"] = "lua/resty/output/init.lua",
		["resty.output.format"] = "lua/resty/output/format.lua",
		["resty.output.statuscode"] = "lua/resty/output/statuscode.lua",
		["resty.output.winbar"] = "lua/resty/output/winbar.lua",
	},
}
