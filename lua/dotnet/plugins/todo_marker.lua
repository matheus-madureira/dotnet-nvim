return {
	"folke/todo-comments.nvim",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = { "nvim-lua/plenary.nvim" },
	opts = {
		keywords = {
			TODO = { icon = " ", color = "info" },
			HACK = { icon = " ", color = "warning" },
			FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "ISSUE" } },
			NOTE = { icon = "󰎞 ", color = "hint", alt = { "INFO", "REMARK" } },
			PERF = { icon = "󰅒 ", alt = { "OPTIMIZE", "PERFORMANCE" } },
		},
	},
	keys = {
		{ "<leader>ft", "<cmd>TodoTelescope<CR>", desc = "Find TODOs" },
	},
}
