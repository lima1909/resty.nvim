local M = {
	ns_diagnostics = vim.api.nvim_create_namespace("resty_diagnostics"),
}

function M.reset(bufnr)
	vim.diagnostic.reset(M.ns_diagnostics, bufnr)
end

function M.check_errors(bufnr, result)
	if not bufnr then
		return false
	end

	M.reset(bufnr)

	if result:has_error() then
		vim.diagnostic.set(M.ns_diagnostics, bufnr, result:errors())
		return true
	end

	return false
end

return M
