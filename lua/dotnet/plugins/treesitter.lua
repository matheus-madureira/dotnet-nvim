return {
	"nvim-treesitter/nvim-treesitter",
	branch = "master",
	event = { "BufReadPre", "BufNewFile" },
	build = ":TSUpdate",
	dependencies = {
		{ "windwp/nvim-ts-autotag", opts = {} },
	},
	config = function()
		local treesitter = require("nvim-treesitter.configs")

		-- Parsers are compiled on install. Without a toolchain nvim-treesitter
		-- throws on every startup, so ask for nothing and say why once.
		local function has_c_compiler()
			for _, compiler in ipairs({ "cc", "gcc", "clang", "cl", "zig" }) do
				if vim.fn.executable(compiler) == 1 then
					return true
				end
			end

			return false
		end

		local compiler_available = has_c_compiler()

		if not compiler_available then
			vim.schedule(function()
				vim.notify(
					"Treesitter parsers need a C compiler. Install one (`winget install zig.zig` "
						.. "on Windows, or your distro's `gcc`/`clang`) and run `:TSUpdate`.",
					vim.log.levels.WARN
				)
			end)
		end

		treesitter.setup({
			highlight = {
				enable = true,
			},
			-- Treesitter indent fights the C# brace style; the LSP formatter wins.
			indent = { enable = false },
			auto_install = compiler_available,
			ensure_installed = compiler_available and {
				"c_sharp",
				"xml", -- .csproj, Directory.Build.props, .targets
				"json",
				"jsonc", -- appsettings.json, global.json
				"yaml",
				"toml",
				"sql",
				"html", -- also used for .razor / .cshtml
				"css",
				"javascript",
				"typescript",
				"bash",
				"lua",
				"vim",
				"vimdoc",
				"query",
				"markdown",
				"markdown_inline",
				"regex",
				"dockerfile",
				"gitignore",
				"git_config",
				"diff",
			} or {},
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "<C-space>",
					node_incremental = "<C-space>",
					scope_incremental = false,
					node_decremental = "<bs>",
				},
			},
		})
	end,
}
