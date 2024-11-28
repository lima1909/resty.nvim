local exec = require("resty.exec")
local format = require("resty.output.format")

local M = {}

M.menu = {
	{
		id = 1,
		keymap = "b",
		name = "body",
		show_window_content = function(slf)
			vim.api.nvim_set_option_value("filetype", "json", { buf = slf.bufnr })

			if slf.cfg.output.body_pretty_print == true then
				exec.jq_wait(1000, slf.current_body, function(json)
					slf.current_body = json
					return true
				end)
			end

			if type(slf.current_body) == "table" then
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, slf.current_body)
			else
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, vim.split(slf.current_body, "\n"))
			end
		end,
	},
	{
		id = 2,
		keymap = "h",
		name = "headers",
		show_window_content = function(slf)
			vim.api.nvim_set_option_value("filetype", "http", { buf = slf.bufnr })
			vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, slf.response.headers)
		end,
	},
	{
		id = 3,
		keymap = "i",
		name = "info",
		show_window_content = function(slf)
			vim.api.nvim_set_option_value("filetype", "markdown", { buf = slf.bufnr })

			slf.parse_result:write_to_buffer(slf.bufnr)

			local buffer_name = slf.call_from_buffer_name or "no buffer found"
			local curl_duration_str = slf.curl.duration_str or ""
			local duration_str = slf.parse_result.duration_str or ""

			-- RESPONSE AND META
			vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, {
				"",
				"## Meta:",
				"",
				"- call from buffer: '" .. buffer_name .. "'",
				"- duration rest-call: " .. curl_duration_str,
				"- duration parse-request: " .. duration_str,
			})

			if exec.is_jq_installed == false then
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, { "", "#  jq is not installed!" })
			end

			-- CURL command
			vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, {
				"",
				"## CURL command:",
				"",
				"```",
				"curl " .. table.concat(slf.curl.job.args or {}, " "),
				"```",
			})
		end,
	},
	{
		id = 4,
		keymap = "?",
		name = "?",
		show_window_content = function(slf)
			vim.api.nvim_set_option_value("filetype", "markdown", { buf = slf.bufnr })

			vim.api.nvim_buf_set_lines(slf.bufnr, 0, -1, false, {
				"## Key shortcuts:",
				"",
				"### Result view:",
				"",
				"| view      | short cut | description         |",
				"|-----------|-----------|---------------------|",
				"| `body`    |   `b`     | response body       |",
				"| `headers` |   `h`     | response headers    |",
				"| `info`    |   `i`     | request information |",
				"| `?`       |   `?`     | help                |",
				"",
				"### Body view:",
				"",
				"| short cut | description                   | ",
				"|-----------|-------------------------------|",
				"| `p`       | json pretty print             |",
				"| `q`       | jq query                      |",
				"| `r`       | reset to the origininal json  |",
				"",
				"`jq` must be installed!",
				"",
				"__Hint:__ with `cc` can the curl call canceled.",
			})
		end,
	},
	{
		id = 5,
		keymap = "e",
		name = "error",
		show_window_content = function(slf)
			vim.api.nvim_set_option_value("filetype", "markdown", { buf = slf.bufnr })

			local message = slf.curl.error.message:gsub("\n", " ")
			local req, _, _, ecode, err = string.match(message, "(.*)(%s%-%s)(curl error%s)(exit_code.*)(stderr.*)")
			req = req or message
			ecode = ecode or ""
			err = err or ""

			vim.api.nvim_buf_set_lines(slf.bufnr, 0, 0, false, {
				"",
				"# curl error",
				"",
				"",
				"```sh",
				req,
				"",
				err,
				ecode,
				"```",
			})
		end,
	},
	{
		id = 6,
		keymap = "d",
		name = "dry_run",
		show_window_content = function(slf)
			vim.api.nvim_set_option_value("filetype", "markdown", { buf = slf.bufnr })

			local curl = format.curl(slf.curl.job.args)
			vim.api.nvim_buf_set_lines(slf.bufnr, 0, 0, false, {
				"",
				"# curl dry run",
				"",
				"## args",
			})

			if curl.args then
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, curl.args)
			end

			local m = curl.method or "no method found"
			local url = curl.url or "no url found"
			vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, { "", "```http", m .. " " .. url })

			if curl.headers then
				vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, curl.headers)
			end

			vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, { "```" })
		end,
	},
	{
		id = 7,
		keymap = "t",
		name = "timeout",
		show_window_content = function(slf)
			vim.api.nvim_set_option_value("filetype", "text", { buf = slf.bufnr })
			vim.api.nvim_buf_set_lines(
				slf.bufnr,
				-1,
				-1,
				false,
				{ "curl is timed out after: " .. slf.curl.timeout .. " ms" }
			)
		end,
	},
	{
		id = 8,
		keymap = "z",
		name = "debug infos",
		show_window_content = function(slf)
			vim.api.nvim_set_option_value("filetype", "lua", { buf = slf.bufnr })
			vim.api.nvim_buf_set_lines(slf.bufnr, -1, -1, false, slf.lines)
		end,
	},
}

M.key_mappings = {
	-- p: pretty print
	["p"] = {
		win_ids = { 1 },
		rhs = function(output)
			exec.jq(output.current_body, function(json)
				output.current_body = json
				output.cfg.output.body_pretty_print = true
				output:select_window(1)
			end)
		end,
		desc = "pretty print with jq",
	},
	-- q: jq query
	q = {
		win_ids = { 1 },
		rhs = function(output)
			local jq_filter = vim.fn.input("Filter: ")
			if jq_filter == "" then
				return
			end
			exec.jq(output.current_body, function(json)
				local new_body = table.concat(json, "\n")
				output.current_body = new_body
				output:select_window(1)
			end, jq_filter)
		end,
		desc = "querying with jq",
	},
	r = {
		win_ids = { 1 },
		rhs = function(output)
			output.current_body = output.response.body
			output.cfg.output.body_pretty_print = false
			output:select_window(1)
		end,
		desc = "reset to the original responsne body",
	},
	zz = {

		win_ids = { 1, nil, 3 },
		rhs = function(output)
			-- toggle for folding
			output.cfg.with_folding = not output.cfg.with_folding
			if output.cfg.with_folding then
				-- if M.config.with_folding then
				vim.cmd("setlocal foldmethod=expr")
				vim.cmd("setlocal foldexpr=v:lua.vim.treesitter.foldexpr()")
				vim.cmd("setlocal foldlevel=2")
			else
				vim.cmd("setlocal foldmethod=manual")
				vim.cmd("normal zE")
			end
		end,
		desc = "toggle folding, if activated",
	},
}

return M
