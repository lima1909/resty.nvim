--
-- https://www.youtube.com/watch?v=HXABdG3xJW4
--

local parser = require("resty.parser")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local utils = require("telescope.previewers.utils")
local config = require("telescope.config").values

local log = require("plenary.log"):new()
log.level = "debug"

M = {
	parser = parser.new(),
}

local output = function(lines, favorite)
	local p = M.parser.parse(lines, favorite.row)
	return {
		"# '" .. favorite.favorite .. "' on row: " .. favorite.row,
		"",
		p.request.method .. " " .. p.request.url,
		"",
	}
end

M.show = function(opts, favorites, lines, exec)
	pickers
		.new(opts, {
			finder = finders.new_table({
				results = favorites,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.favorite,
						ordinal = entry.favorite .. ":" .. entry.row,
					}
				end,
			}),
			sorter = config.generic_sorter(opts),
			previewer = previewers.new_buffer_previewer({
				title = "Favorites",
				define_preview = function(self, entry)
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, 0, true, output(lines, entry.value))
					utils.highlighter(self.state.bufnr, "http")
				end,
			}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					exec(selection.value.row)

					return selection.value
				end)
				return true
			end,
		})
		:find()
end

return M
