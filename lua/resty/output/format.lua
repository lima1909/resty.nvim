local M = {}

M.duration = function(time)
	if not time then
		return "no time avialable"
	end

	local units = { "s", "ms", "µs", "ns" }
	local current_unit_pos = 1

	while time < 1 and current_unit_pos <= #units do
		time = time * 1000
		current_unit_pos = current_unit_pos + 1
	end

	return string.format("%.2f %s", time, units[current_unit_pos])
end

return M
