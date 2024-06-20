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
test = {
	type = "busted",
}
