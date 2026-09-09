return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
		{ "folke/lazydev.nvim", ft = "lua", opts = {} },
	},
	config = function()
		local keymap = vim.keymap

		-- setup keymaps when LSP attaches
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				local opts = { buffer = ev.buf, silent = true }

				opts.desc = "Show LSP references"
				keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", opts)

				opts.desc = "Go to declaration"
				keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

				opts.desc = "Go to definition"
				keymap.set("n", "gd", vim.lsp.buf.definition, opts)

				opts.desc = "Show LSP implementations"
				keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts)

				opts.desc = "Show LSP type definitions"
				keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts)

				opts.desc = "See available code actions"
				keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)

				opts.desc = "Smart rename"
				keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

				opts.desc = "Show buffer diagnostics"
				keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts)

				opts.desc = "Show line diagnostics"
				keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

				opts.desc = "Go to previous diagnostic"
				keymap.set("n", "[d", function()
					vim.diagnostic.jump({ count = -1, float = true })
				end, opts)

				opts.desc = "Go to next diagnostic"
				keymap.set("n", "]d", function()
					vim.diagnostic.jump({ count = 1, float = true })
				end, opts)

				opts.desc = "Show documentation under cursor"
				keymap.set("n", "K", vim.lsp.buf.hover, opts)

				opts.desc = "Signature help"
				keymap.set("i", "<C-s>", vim.lsp.buf.signature_help, opts)

				opts.desc = "Restart LSP"
				keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts)

				-- Enable inlay hints if supported
				local client = vim.lsp.get_client_by_id(ev.data.client_id)
				if client and client:supports_method("textDocument/inlayHint") then
					vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
				end
			end,
		})

		keymap.set("n", "<leader>ih", function()
			local bufnr = vim.api.nvim_get_current_buf()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
		end, { desc = "Toggle inlay hints" })

		-- LSP completion capabilities
		local capabilities = require("cmp_nvim_lsp").default_capabilities()

		-- diagnostic signs and inline diagnostics
		vim.diagnostic.config({
			-- tiny-inline-diagnostic.nvim draws the end-of-line diagnostics itself
			-- (see `lua/dotnet/plugins/tiny-inline-diagnostic.lua`); leaving the
			-- built-in virtual text on would print every message twice.
			virtual_text = false,
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = " ",
					[vim.diagnostic.severity.WARN] = " ",
					[vim.diagnostic.severity.HINT] = "󰠠 ",
					[vim.diagnostic.severity.INFO] = " ",
				},
			},
			underline = true,
			update_in_insert = false,
			severity_sort = true,
		})

		-- ============================
		-- C# / OmniSharp (opt-in fallback)
		--
		-- roslyn.nvim owns C# by default. Set `vim.g.dotnet_lsp = "omnisharp"`
		-- in lua/dotnet/core/options.lua to use OmniSharp instead; the two are
		-- mutually exclusive so diagnostics are never reported twice.
		-- ============================
		if vim.g.dotnet_lsp == "omnisharp" then
			vim.lsp.config("omnisharp", {
				capabilities = capabilities,
				settings = {
					FormattingOptions = {
						-- Same source of truth as Roslyn: the workspace
						-- `.editorconfig` seeded from templates/dotnet.editorconfig.
						EnableEditorConfigSupport = true,
						OrganizeImports = true,
					},
					RoslynExtensionsOptions = {
						EnableAnalyzersSupport = true,
						EnableImportCompletion = true,
						AnalyzeOpenDocumentsOnly = false,
					},
					Sdk = {
						IncludePrereleases = true,
					},
				},
			})

			vim.lsp.enable("omnisharp")
		end

		-- ============================
		-- XML (MSBuild project files)
		-- ============================
		vim.lsp.config("lemminx", {
			capabilities = capabilities,
			filetypes = { "xml", "xsd", "xsl", "xslt", "svg" },
		})

		vim.lsp.enable("lemminx")

		-- ============================
		-- JSON (appsettings, global.json, launchSettings)
		-- ============================
		vim.lsp.config("jsonls", {
			capabilities = capabilities,
			settings = {
				json = {
					validate = { enable = true },
				},
			},
		})

		vim.lsp.enable("jsonls")

		-- ============================
		-- YAML (CI pipelines, docker-compose)
		-- ============================
		vim.lsp.config("yamlls", {
			capabilities = capabilities,
			settings = {
				yaml = {
					keyOrdering = false,
				},
			},
		})

		vim.lsp.enable("yamlls")

		-- ============================
		-- Lua (this config)
		-- ============================
		vim.lsp.config("lua_ls", {
			capabilities = capabilities,
			settings = {
				Lua = {
					runtime = {
						version = "LuaJIT",
					},
					diagnostics = {
						globals = { "vim" },
					},
					workspace = {
						checkThirdParty = false,
						library = vim.api.nvim_get_runtime_file("", true),
					},
					completion = {
						callSnippet = "Replace",
					},
				},
			},
		})

		vim.lsp.enable("lua_ls")
	end,
}
