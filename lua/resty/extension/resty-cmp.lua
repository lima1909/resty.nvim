-- https://www.jonashietala.se/blog/2024/05/26/autocomplete_with_nvim-cmp/

local cmp = require("cmp")
--
-- WARN: register: in after/plugin/resty.lua the completion
--
local M = {}

M.new = function()
	-- print("-- resty-cmp.new --")
	return setmetatable({}, { __index = M })
end

function M:complete(r, callback)
	local input = r.context.cursor_before_line
	print("-- " .. input)
	-- print(vim.inspect(r))

	local entries = {
		{ word = "ab", label = "abc", menu = "[Resty]", cmp = { kind_hl_group = "@keyword.sql", kind_text = "sql" } },
		{ label = "axyz", documentation = { kind = "markdown", value = [[
# my help
<hr>
_text_ 
* axyz
		]] } },
		{
			label = "aoo",
			insertText = "ooa",
			kind = cmp.lsp.CompletionItemKind.Value,
			menu = "[Resty]",
			detail = "Details ...",
			documentation = {
				kind = "plaintext",
				value = [[

*MY-PLUGIN*                 Plugin documentation for My Plugin

INTRODUCTION~

This is a *brief introduction* to the plugin.

- Item 1
- Item 2

USAGE~

    :MyCommand

Example:
     :lua print("Hello, World!")

Runs the main command of the plugin.

OPTIONS~

    'myoption'
        Description of the option.

See also |other-plugin| for related functionality.

				]],
			},
		},
	}

	callback(entries)
end

return M
