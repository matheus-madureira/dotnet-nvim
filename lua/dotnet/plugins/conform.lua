return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo", "Format", "FormatDisable", "FormatEnable" },
	config = function()
		local conform = require("conform")

		conform.setup({
			formatters_by_ft = {
				-- CSharpier when it is installed; otherwise `lsp_format` below
				-- falls back to Roslyn's own formatter. Either way the whitespace
				-- rules come from the `.editorconfig` in the workspace -- the
				-- default one lives in `templates/dotnet.editorconfig` and is
				-- installed by `lua/dotnet/tools/editorconfig.lua`.
				cs = { "csharpier" },
				lua = { "stylua" },
				json = { "prettier" },
				jsonc = { "prettier" },
				yaml = { "prettier" },
				markdown = { "prettier" },
				xml = { "xmlformatter" },
			},
			default_format_opts = {
				lsp_format = "fallback",
			},
			format_on_save = function(bufnr)
				-- Opt out per buffer with `:lua vim.b.disable_autoformat = true`,
				-- or globally with `:FormatDisable`.
				if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
					return
				end

				return { timeout_ms = 3000, lsp_format = "fallback" }
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

			conform.format({ async = true, lsp_format = "fallback", range = range })
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
			conform.format({ async = true, lsp_format = "fallback" })
		end, { desc = "Format file or range" })
	end,
}
