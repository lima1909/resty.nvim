local M = {
	ns_diagnostics = vim.api.nvim_create_namespace("resty_diagnostics"),
}

function M.reset(bufnr)
	vim.diagnostic.reset(M.ns_diagnostics, bufnr)
end

function M.show(bufnr, result)
	if not bufnr then
		return false
	end

	M.reset(bufnr)

	if result:has_diag() then
		vim.diagnostic.set(M.ns_diagnostics, bufnr, result.diagnostics)
		return true
	end

	return false
end

return M
