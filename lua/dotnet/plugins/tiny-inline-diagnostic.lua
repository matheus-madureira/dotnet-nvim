return {
	"rachartier/tiny-inline-diagnostic.nvim",
	event = "VeryLazy",
	priority = 1000,
	config = function()
		require("tiny-inline-diagnostic").setup({
			preset = "modern",

			options = {
				-- Roslyn reports the analyzer id (`CS0246`, `IDE0090`, ...), and it
				-- is the id -- not the prose -- that maps back to a rule in the
				-- workspace `.editorconfig`, so keep it in the line.
				show_code = true,

				-- The source only earns its place when two of them land on the same
				-- line, which for C# means Roslyn plus a third-party analyzer.
				show_source = {
					enabled = true,
					if_many = true,
				},

				-- Reuse the sign icons configured in `lsp/lspconfig.lua` instead of
				-- the preset's own, so a warning looks the same in the gutter and
				-- at the end of the line.
				use_icons_from_diagnostic = true,
				set_arrow_to_diag_color = true,

				-- Roslyn messages get long ("cannot convert from 'X' to 'Y'" with
				-- fully qualified generics). Wrap the overflow onto the lines below
				-- rather than truncating it, but only for the diagnostic under the
				-- cursor -- `always_show` would push the whole buffer around.
				multilines = {
					enabled = true,
					always_show = false,
				},

				-- Matches `update_in_insert = false`: diagnostics from a half-typed
				-- line are noise, and the virtual text moving as you type is worse.
				enable_on_insert = false,
				enable_on_select = false,
			},

			-- Buffers that are UI, not code.
			disabled_ft = {
				"alpha",
				"NvimTree",
				"TelescopePrompt",
				"trouble",
				"dap-repl",
				"neotest-summary",
				"neotest-output-panel",
			},
		})

		vim.keymap.set("n", "<leader>id", function()
			require("tiny-inline-diagnostic").toggle()
		end, { desc = "Toggle inline diagnostics" })
	end,
}
