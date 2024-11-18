local ok, cmp = pcall(require, "cmp")
if ok then
	-- add resty completion, if nvim-cmp is installed
	cmp.register_source("resty", require("resty.extension.resty-cmp").new())
	cmp.setup.filetype({ "resty", "http" }, {
		sources = cmp.config.sources({
			{ name = "resty" },
			{ name = "buffer" },
			{ name = "text" },
			{ name = "path" },
		}),
	})
end
