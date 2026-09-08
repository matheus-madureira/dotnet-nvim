return {
	"folke/trouble.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {},
	keys = {
		{ "<leader>tt", "<cmd>Trouble diagnostics toggle<CR>", desc = "Workspace diagnostics" },
		{ "<leader>tb", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Buffer diagnostics" },
		{ "<leader>tq", "<cmd>Trouble qflist toggle<CR>", desc = "Quickfix list" },
	},
}
