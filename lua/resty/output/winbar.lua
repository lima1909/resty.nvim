--
-- vim.api.nvim_create_namespace("Resty"),
vim.api.nvim_set_hl(0, "ActiveWin", { underdouble = true, bold = true }) -- NOTE: doesn't work with nvim 9: force = true
vim.api.nvim_set_hl(0, "StatusOK", { fg = "grey" })
vim.api.nvim_set_hl(0, "StatusNotOK", { fg = "red" })

local function menu_entry(entry, selected)
	local text = entry.name

	if selected == true then
		text = "%#ActiveWin#" .. text .. "%*"
	end

	return "%" .. entry.id .. "@v:lua._G._resty_select_window@" .. text .. "%X"
end

local function winbar_str(menu_entries, selected_entry, status_def, duration_str)
	local selected = selected_entry or 0

	local winbar = "| "
	for _, entry in ipairs(menu_entries) do
		winbar = winbar .. menu_entry(entry, entry.id == selected) .. " | "
	end

	local status_hl = "%#StatusOK#"
	if not status_def.is_ok then
		status_hl = "%#StatusNotOK#"
	end

	return winbar .. "  " .. status_hl .. status_def.code .. " " .. status_def.text .. " (" .. duration_str .. ")%*"
end

local M = {}

function M:select(selected_entry)
	local s = winbar_str(self.menu_entries, selected_entry, self.status_def, self.duration_str)
	vim.wo[self.winnr].winbar = s
	return s
end

-- a menu_entry consists id and a text: { id = "1", text="entry"}
-- status_def: { code = "", text = "curl error", is_ok = false }
function M.new(winnr, menu_entries, status_def, duration_str)
	M.winnr = winnr
	M.menu_entries = menu_entries
	M.status_def = status_def
	M.duration_str = duration_str

	return M
end

return M
