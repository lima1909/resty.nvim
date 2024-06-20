rockspec_format = "3.0"
package = "resty.nvim"
version = "scm-1"

description = {
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
}

test_dependencies = {
	"plenary.nvim",
	"luassert",
}
