return {
	"mason-org/mason.nvim",
	dependencies = {
		"mason-org/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	config = function()
		local mason = require("mason")
		local mason_lspconfig = require("mason-lspconfig")
		local mason_tool_installer = require("mason-tool-installer")

		mason.setup({
			-- The Roslyn language server is not in the default registry; it is
			-- published in the community one that roslyn.nvim tracks. Without
			-- this, `:MasonInstall roslyn` fails and C# gets no LSP at all.
			registries = {
				"github:mason-org/mason-registry",
				"github:crashdummyy/mason-registry",
			},
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		mason_lspconfig.setup({
			-- Servers configured through nvim-lspconfig. The C# server is not in
			-- this list: roslyn.nvim owns it (see roslyn.lua).
			ensure_installed = {
				"lua_ls",
				"jsonls",
				"yamlls",
				"lemminx", -- XML: .csproj, Directory.Build.props, .targets
			},
			-- We call `vim.lsp.enable()` explicitly in lspconfig.lua.
			automatic_enable = false,
		})

		mason_tool_installer.setup({
			ensure_installed = {
				"roslyn", -- Microsoft.CodeAnalysis.LanguageServer, driven by roslyn.nvim
				"netcoredbg", -- .NET debug adapter for nvim-dap
				"csharpier", -- opinionated C# formatter
				"tree-sitter-cli", -- required by nvim-treesitter `main` to build parsers
				"stylua", -- for this config's own Lua files
			},
			run_on_start = true,
			auto_update = false,
		})
	end,
}
