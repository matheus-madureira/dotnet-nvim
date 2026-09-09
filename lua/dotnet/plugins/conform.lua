return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo", "Format", "FormatDisable", "FormatEnable" },
	config = function()
		local conform = require("conform")

		--- Which engine gets to format a buffer.
		---
		--- For C# the answer is the language server: Roslyn's formatter is the one
		--- that reads `csharp_new_line_*`, `csharp_space_*`, `csharp_indent_*` and
		--- the rest of the whitespace section of the workspace `.editorconfig`
		--- (`templates/dotnet.editorconfig`), so saving a file applies exactly the
		--- rules the diagnostics are complaining about. CSharpier is opinionated
		--- by design -- it reads indentation, line ending and print width and
		--- decides everything else itself -- so it would quietly overrule the
		--- ruleset. It stays as the fallback for what the server cannot do
		--- (formatting a range, or a buffer with no server attached), and
		--- `vim.g.dotnet_formatter = "csharpier"` puts it back in charge.
		local function lsp_format(bufnr)
			bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr

			if vim.bo[bufnr].filetype == "cs" and vim.g.dotnet_formatter ~= "csharpier" then
				return "prefer"
			end

			return "fallback"
		end

		local formatters_by_ft = {
			-- Roslyn formats C# (see `lsp_format` above); CSharpier is the
			-- fallback, and takes over when `vim.g.dotnet_formatter` says so.
			cs = { "csharpier" },
			lua = { "stylua" },
			json = { "prettier" },
			jsonc = { "prettier" },
			yaml = { "prettier" },
			markdown = { "prettier" },
			xml = { "xmlformatter" },
		}

		conform.setup({
			formatters_by_ft = formatters_by_ft,
			default_format_opts = {
				lsp_format = "fallback",
			},
			format_on_save = function(bufnr)
				-- Opt out per buffer with `:lua vim.b.disable_autoformat = true`,
				-- or globally with `:FormatDisable`.
				if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
					return
				end

				local filetype = vim.bo[bufnr].filetype

				-- Roslyn only answers a formatting request once the solution behind
				-- the file has finished loading, and on a real solution that takes
				-- longer than the first save after opening Neovim. Three seconds is
				-- plenty for a local formatter and not enough for the server, and a
				-- request that times out formats nothing at all -- `"prefer"` hands
				-- the buffer to the server, so CSharpier does not pick up the pieces.
				local timeout_ms = filetype == "cs" and 10000 or 3000

				return { timeout_ms = timeout_ms, lsp_format = lsp_format(bufnr) }, function(err)
					-- A save that formatted nothing looks exactly like a save that
					-- formatted an already-clean file: no message, no change. Say so
					-- out loud instead, but only for the filetypes that are supposed
					-- to be formatted -- every other buffer legitimately has no
					-- formatter and would warn on every write.
					if not err or not formatters_by_ft[filetype] then
						return
					end

					local message = type(err) == "table" and (err.message or vim.inspect(err)) or tostring(err)
					vim.notify("Format on save: " .. message, vim.log.levels.WARN)
				end
			end,
		})

		vim.api.nvim_create_user_command("Format", function(args)
			local range = nil
			if args.count ~= -1 then
				local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
				range = {
					start = { args.line1, 0 },
					["end"] = { args.line2, end_line:len() },
				}
			end

			conform.format({ async = true, lsp_format = lsp_format(0), range = range })
		end, { range = true, desc = "Format buffer or range" })

		vim.api.nvim_create_user_command("FormatDisable", function(args)
			if args.bang then
				vim.b.disable_autoformat = true
			else
				vim.g.disable_autoformat = true
			end
		end, { bang = true, desc = "Disable format on save (! for this buffer only)" })

		vim.api.nvim_create_user_command("FormatEnable", function()
			vim.b.disable_autoformat = false
			vim.g.disable_autoformat = false
		end, { desc = "Re-enable format on save" })

		vim.keymap.set({ "n", "v" }, "<leader>mp", function()
			conform.format({ async = true, lsp_format = lsp_format(0) })
		end, { desc = "Format file or range" })
	end,
}
