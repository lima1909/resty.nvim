-- print(vim.api.nvim_buf_get_name(0))
--
-- https://www.youtube.com/watch?v=HXABdG3xJW4
--
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local utils = require("telescope.previewers.utils")
local config = require("telescope.config").values

local log = require("plenary.log"):new()
log.level = "debug"

M = {}

M.view = function(opts)
	local pathes = vim.api.nvim_list_runtime_paths()

	local list = {}
	for k, p in ipairs(pathes) do
		table.insert(list, { number = k, path = p })
	end

	pickers
		.new(opts, {
			-- finder = finders.new_table(pathes),
			finder = finders.new_table({
				results = list,
				entry_maker = function(entry)
					-- log.debug(entry)

					return {
						value = entry,
						display = entry.path,
						ordinal = entry.path,
					}
				end,
			}),
			sorter = config.generic_sorter(opts),
			previewer = previewers.new_buffer_previewer({
				title = "Pathes",
				define_preview = function(self, entry)
					vim.api.nvim_buf_set_lines(
						self.state.bufnr,
						0,
						0,
						true,
						vim.tbl_flatten({ '{"name": "blug"}', vim.split(vim.inspect(entry), "\n", opts) })
					)
					utils.highlighter(self.state.bufnr, "json")
				end,
			}),
		})
		:find()
end

return M
