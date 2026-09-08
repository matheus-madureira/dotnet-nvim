-- xUnit / NUnit / MSTest discovery and running, with the results rendered next
-- to the code instead of scraped out of `dotnet test` output.
return {
	"nvim-neotest/neotest",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-neotest/nvim-nio",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		"Issafalcon/neotest-dotnet",
		"mfussenegger/nvim-dap",
	},
	config = function()
		local neotest = require("neotest")

		neotest.setup({
			adapters = {
				require("neotest-dotnet")({
					dap = {
						-- Step into framework code too, not just your own.
						args = { justMyCode = false },
						adapter_name = "coreclr",
					},
					-- Discover every test project in the solution, not just the
					-- one owning the current file.
					discovery_root = "solution",
				}),
			},
			quickfix = {
				open = false,
			},
		})

		local keymap = vim.keymap
		keymap.set("n", "<leader>tr", function()
			neotest.run.run()
		end, { desc = "Run nearest test" })

		keymap.set("n", "<leader>tf", function()
			neotest.run.run(vim.fn.expand("%"))
		end, { desc = "Run tests in file" })

		keymap.set("n", "<leader>ta", function()
			neotest.run.run(require("dotnet.tools.project").root())
		end, { desc = "Run all tests in solution" })

		keymap.set("n", "<leader>td", function()
			neotest.run.run({ strategy = "dap" })
		end, { desc = "Debug nearest test" })

		keymap.set("n", "<leader>tx", function()
			neotest.run.stop()
		end, { desc = "Stop test run" })

		keymap.set("n", "<leader>tS", function()
			neotest.summary.toggle()
		end, { desc = "Toggle test summary" })

		keymap.set("n", "<leader>to", function()
			neotest.output.open({ enter = true, auto_close = true })
		end, { desc = "Show test output" })

		keymap.set("n", "<leader>tO", function()
			neotest.output_panel.toggle()
		end, { desc = "Toggle test output panel" })
	end,
}
