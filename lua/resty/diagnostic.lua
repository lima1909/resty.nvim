local M = {
	ns_diagnostics = vim.api.nvim_create_namespace("resty_diagnostics"),
}

function M.reset(bufnr)
	vim.diagnostic.reset(M.ns_diagnostics, bufnr)
end

function M.show(bufnr, parser_result)
	if not bufnr then
		return false
	end

	M.reset(bufnr)

	if parser_result:has_errors() then
		vim.diagnostic.set(M.ns_diagnostics, bufnr, parser_result.errors)
		return true
	end

	return false
end

return M
