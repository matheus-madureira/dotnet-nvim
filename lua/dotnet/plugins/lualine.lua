return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local lualine = require("lualine")
		local lazy_status = require("lazy.status") -- to configure lazy pending updates count
		local project = require("dotnet.tools.project")

		-- Show which .csproj owns the current buffer.
		local function current_project()
			local csproj = project.find_csproj()
			if not csproj then
				return ""
			end

			return "󰪮 " .. vim.fn.fnamemodify(csproj, ":t:r")
		end

		lualine.setup({
			options = {
				theme = "auto",
			},
			sections = {
				lualine_b = {
					{ "branch" },
					{ "diagnostics" },
				},
				lualine_c = {
					{ "filename", path = 1 },
					{ current_project },
				},
				lualine_x = {
					{
						lazy_status.updates,
						cond = lazy_status.has_updates,
					},
					{ "encoding" },
					{ "fileformat" },
					{ "filetype" },
				},
			},
		})

		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("DotnetLualineThemeSync", { clear = true }),
			callback = function()
				lualine.refresh()
			end,
		})
	end,
}
