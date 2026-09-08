-- Microsoft's Roslyn language server (the engine behind the official C# VS Code
-- extension). Installed by Mason as the `roslyn` package; roslyn.nvim locates it
-- and handles solution / project detection.
return {
	"seblyng/roslyn.nvim",
	-- Not `ft = "cs"`: the plugin calls `vim.lsp.enable("roslyn")` as soon as it
	-- loads, and on the FileType that loaded it the server can attach before
	-- `setup()` has applied the options below -- losing `choose_target` for the
	-- first C# buffer of the session. Loading at startup fixes the order; the
	-- server itself still only starts once a C# buffer exists.
	lazy = false,
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
	},
	opts = {
		-- "auto" uses Neovim's file watcher when the server asks for one, which
		-- is much cheaper than Roslyn's own polling on large solutions.
		filewatching = "auto",

		-- A repo migrated to the new solution format often keeps both `Foo.sln`
		-- and `Foo.slnx`. They describe the same projects, so leaving the server
		-- unattached and asking every time is noise; prefer the newer format.
		-- Genuinely different solutions are still a real choice and fall through
		-- to `:Roslyn target`.
		choose_target = function(targets)
			local stems = {}
			for _, target in ipairs(targets) do
				stems[vim.fn.fnamemodify(target, ":r")] = true
			end

			if vim.tbl_count(stems) ~= 1 then
				return nil
			end

			for _, target in ipairs(targets) do
				if vim.endswith(target, ".slnx") then
					return target
				end
			end

			return targets[1]
		end,
	},
	config = function(_, opts)
		if vim.g.dotnet_lsp ~= "roslyn" then
			return
		end

		vim.lsp.config("roslyn", {
			capabilities = require("cmp_nvim_lsp").default_capabilities(),
			settings = {
				["csharp|background_analysis"] = {
					dotnet_analyzer_diagnostics_scope = "fullSolution",
					dotnet_compiler_diagnostics_scope = "fullSolution",
				},
				["csharp|inlay_hints"] = {
					csharp_enable_inlay_hints_for_implicit_object_creation = true,
					csharp_enable_inlay_hints_for_implicit_variable_types = true,
					csharp_enable_inlay_hints_for_lambda_parameter_types = true,
					csharp_enable_inlay_hints_for_types = true,
					dotnet_enable_inlay_hints_for_indexer_parameters = true,
					dotnet_enable_inlay_hints_for_literal_parameters = true,
					dotnet_enable_inlay_hints_for_object_creation_parameters = true,
					dotnet_enable_inlay_hints_for_other_parameters = true,
					dotnet_enable_inlay_hints_for_parameters = true,
				},
				["csharp|code_lens"] = {
					dotnet_enable_references_code_lens = true,
					dotnet_enable_tests_code_lens = true,
				},
				["csharp|completion"] = {
					dotnet_provide_regex_completions = true,
					dotnet_show_completion_items_from_unimported_namespaces = true,
					dotnet_show_name_completion_suggestions = true,
				},
				["csharp|symbol_search"] = {
					dotnet_search_reference_assemblies = true,
				},
			},
		})

		require("roslyn").setup(opts)

		vim.keymap.set("n", "<leader>rt", "<cmd>Roslyn target<CR>", { desc = "Pick Roslyn solution target" })
		vim.keymap.set("n", "<leader>rr", "<cmd>Roslyn restart<CR>", { desc = "Restart Roslyn" })
	end,
}
