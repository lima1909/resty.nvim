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

M = {}

M.show = function(favorites, lines, exec, opts)
	pickers
		.new(opts, {
			finder = finders.new_table({
				results = favorites,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.favorite .. " (row: " .. entry.row .. ")",
						ordinal = entry.favorite .. ":" .. entry.row,
					}
				end,
			}),
			sorter = config.generic_sorter(opts),
			previewer = previewers.new_buffer_previewer({
				title = "Favorites",
				define_preview = function(self, entry)
					local bufnr = self.state.bufnr
					local favorite = entry.value
					parser.parse(lines, favorite.row):write_to_buffer(bufnr)
					utils.highlighter(bufnr, "markdown")
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
