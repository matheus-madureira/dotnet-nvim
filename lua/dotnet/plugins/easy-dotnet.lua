-- Solution-level operations that the language server does not cover: creating
-- projects, adding project/package references, user secrets, EF Core migrations.
return {
	"GustavEikaas/easy-dotnet.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope.nvim",
	},
	-- Loaded on demand only: `setup()` spawns a background `dotnet` RPC server,
	-- which is not worth paying for in every C# buffer when this plugin is here
	-- for occasional solution-level work.
	cmd = { "Dotnet" },
	keys = {
		{ "<leader>pn", "<cmd>Dotnet new<CR>", desc = "New project from template" },
		{ "<leader>pp", "<cmd>Dotnet project<CR>", desc = "Pick project" },
		{ "<leader>po", "<cmd>Dotnet outdated<CR>", desc = "Outdated NuGet packages" },
		{ "<leader>pk", "<cmd>Dotnet secrets<CR>", desc = "Edit user secrets" },
	},
	config = function()
		require("easy-dotnet").setup({
			terminal = function(path, action, args)
				local commands = {
					run = function()
						return string.format("dotnet run --project %s %s", path, args)
					end,
					test = function()
						return string.format("dotnet test %s %s", path, args)
					end,
					restore = function()
						return string.format("dotnet restore %s %s", path, args)
					end,
					build = function()
						return string.format("dotnet build %s %s", path, args)
					end,
					watch = function()
						return string.format("dotnet watch --project %s %s", path, args)
					end,
				}

				local command = commands[action]() .. "\r"
				vim.cmd("botright new")
				vim.cmd("term " .. command)
				vim.api.nvim_win_set_height(0, 15)
			end,
			auto_bootstrap_namespace = {
				type = "file_scoped",
				enabled = true,
			},
		})
	end,
}
