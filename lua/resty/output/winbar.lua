--
-- vim.api.nvim_create_namespace("Resty"),
vim.api.nvim_set_hl(0, "ActiveWin", { underdouble = true, bold = true, force = true })
vim.api.nvim_set_hl(0, "StatusOK", { fg = "grey" })
vim.api.nvim_set_hl(0, "StatusNotOK", { fg = "red" })

local function menu_entry(entry, selected)
	local text = entry.text

	if selected == true then
		text = "%#ActiveWin#" .. text .. "%*"
	end

	return "%" .. entry.id .. "@v:lua._G._resty_select_window@" .. text .. "%X"
end

local function winbar_str(menu_entries, selected_entry, status_def, duration_str)
	local selected = selected_entry or 0

	local winbar = "| "
	for _, entry in pairs(menu_entries) do
		winbar = winbar .. menu_entry(entry, entry.id == selected) .. " | "
	end

	local status_hl = "%#StatusOK#"
	if not status_def.is_ok then
		status_hl = "%#StatusNotOK#"
	end

	return winbar .. "  " .. status_hl .. status_def.code .. " " .. status_def.text .. " (" .. duration_str .. ")%*"
end

local function init_winbar_menu_and_windows_keymaps(output)
	local menu = {}
	for id, win in pairs(output.windows) do
		table.insert(menu, { id = id, text = win.name })

		-- create keymaps for the given window
		vim.keymap.set("n", win.keymap, function()
			output:select_window(id)
		end, { buffer = output.bufnr, silent = true })
	end

	return menu
end

local M = {}

function M:select(selected_entry, status_def, duration_str)
	local s = winbar_str(self.menu_entries, selected_entry, status_def, duration_str)
	vim.wo[self.winnr].winbar = s
	return s
end

-- a menu_entry consists id and a text: { id = "1", text="entry"}
function M.new(output)
	M.bufnr = output.bufnr
	M.winnr = output.winnr
	M.menu_entries = init_winbar_menu_and_windows_keymaps(output)

	return M
end

return M
