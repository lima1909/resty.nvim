--
-- https://www.youtube.com/watch?v=HXABdG3xJW4
--

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

local output = function(req_def)
	local out = {
		"# " .. req_def.name .. " [" .. req_def.start_at .. " - " .. req_def.end_at .. "]",
		"",
		"```lua",
		"method: " .. req_def.method,
		"URL: " .. req_def.url,
		"query:" .. vim.tbl_flatten({ vim.split(vim.inspect(req_def.req.query), "\n") }),
		"```",
	}
	-- return vim.tbl_flatten({ vim.split(vim.inspect(req_def), "\n") })
	return out
end

M.view = function(opts, req_defs, exec)
	-- convert request definitions
	local list = {}
	for _, d in pairs(req_defs) do
		table.insert(list, d)
	end

	pickers
		.new(opts, {
			finder = finders.new_table({
				results = list,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.name,
						ordinal = entry.name .. ":" .. entry.req.method .. ":" .. entry.req.url,
					}
				end,
			}),
			sorter = config.generic_sorter(opts),
			previewer = previewers.new_buffer_previewer({
				title = "Request definitions",
				define_preview = function(self, entry)
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, 0, true, output(entry.value))
					utils.highlighter(self.state.bufnr, "markdown")
				end,
			}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					exec(selection.value)

					return selection.value
				end)
				return true
			end,
		})
		:find()
end

return M
