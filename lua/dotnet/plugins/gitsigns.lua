return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		current_line_blame = false,
	},
	keys = {
		{ "<leader>gb", "<cmd>Gitsigns toggle_current_line_blame<CR>", desc = "Toggle line blame" },
		{ "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", desc = "Preview hunk" },
	},
}
