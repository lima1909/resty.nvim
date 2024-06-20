rockspec_format = "3.0"
package = "resty.nvim"
version = "scm-1"

description = {
	labels = { "neovim" },
	license = "MIT",
}

dependencies = {
	"lua >= 5.1, < 5.4",
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
		"lua",
		"spec",
	},
}

test_dependencies = {
	"plenary.nvim",
}

test = {
	type = "busted",
	platforms = {
		windows = {
			flags = { "--exclude-tags=ssh,git,unix", "-Xhelper", "lua_dir=$(LUA_DIR)", "-Xhelper", "lua=$(LUA)" },
		},
		unix = {
			flags = { "--exclude-tags=ssh,git", "-Xhelper", "lua_dir=$(LUA_DIR)", "-Xhelper", "lua=$(LUA)" },
		},
	},
}
