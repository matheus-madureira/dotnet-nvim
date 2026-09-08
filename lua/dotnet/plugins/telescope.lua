return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{
			"nvim-telescope/telescope-fzf-native.nvim",
			build = "make",
			cond = function()
				return vim.fn.executable("make") == 1
			end,
		},
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")

		telescope.setup({
			defaults = {
				file_ignore_patterns = {
					"node_modules",
					-- `%p` is any separator, so this catches .vs/ and .vs\ but
					-- not .vscode. Visual Studio caches stale solution copies there.
					"%.vs%p",
					"%.git[/\\]",
					"[/\\]bin[/\\]",
					"[/\\]obj[/\\]",
					"%.dll$",
					"%.pdb$",
					"%.nupkg$",
					"%.user$",
				},
				path_display = { "smart" },
				mappings = {
					i = {
						["<C-k>"] = actions.move_selection_previous,
						["<C-j>"] = actions.move_selection_next,
						["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
						["<C-t>"] = require("trouble.sources.telescope").open,
					},
				},
			},
		})

		pcall(telescope.load_extension, "fzf")

		local keymap = vim.keymap
		keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files" })
		keymap.set("n", "<leader>fw", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
		keymap.set("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", { desc = "Find document symbols" })
		keymap.set("n", "<leader>fS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", {
			desc = "Find workspace symbols",
		})
		keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", {
			desc = "Find string under cursor in cwd",
		})
		keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find open buffers" })
		keymap.set("n", "<leader>fp", function()
			require("telescope.builtin").find_files({
				prompt_title = "Project files (.csproj / .sln)",
				find_command = { "rg", "--files", "--glob", "*.csproj", "--glob", "*.sln", "--glob", "*.slnx" },
			})
		end, { desc = "Find .csproj / .sln files" })
	end,
}
