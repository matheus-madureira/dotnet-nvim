vim.cmd("let g:netrw_liststyle = 3")

-- Which C# language server to drive: "roslyn" (default, via roslyn.nvim) or
-- "omnisharp" (via nvim-lspconfig). Only one ever attaches to a buffer.
vim.g.dotnet_lsp = vim.g.dotnet_lsp or "roslyn"

-- Configuration used by `dotnet build` / `dotnet run` / the debugger.
vim.g.dotnet_configuration = vim.g.dotnet_configuration or "Debug"

-- What formats C# on save: "lsp" (default) runs the Roslyn formatter, which is
-- the one that applies the whitespace rules from `.editorconfig`; "csharpier"
-- hands the file to CSharpier instead, which imposes its own layout.
vim.g.dotnet_formatter = vim.g.dotnet_formatter or "lsp"

-- Whether a workspace with no `.editorconfig` of its own gets the default C#
-- ruleset from `templates/dotnet.editorconfig`. That file is what carries the
-- style, naming and analyzer severity rules to the language server *and* to the
-- formatter; `false` leaves projects alone and keeps `:DotnetEditorConfig`.
if vim.g.dotnet_editorconfig == nil then
	vim.g.dotnet_editorconfig = true
end

local opt = vim.opt

opt.relativenumber = true
opt.number = true

-- tabs / indentation (dotnet convention: 4 spaces)
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true
opt.copyindent = true
opt.preserveindent = true

opt.wrap = false

opt.ignorecase = true
opt.smartcase = true

opt.cursorline = true

opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"

opt.backspace = "indent,eol,start"

opt.clipboard:append("unnamedplus")

opt.splitright = true
opt.splitbelow = true

-- C# regions double as fold markers
opt.foldmethod = "marker"
opt.foldmarker = "#region,#endregion"

vim.api.nvim_create_autocmd("FileType", {
	callback = function(args)
		local bo = vim.bo[args.buf]
		bo.autoindent = true
		bo.smartindent = true
		bo.copyindent = true
		bo.preserveindent = true
	end,
})

-- MSBuild / XML project files want 2 spaces, not 4.
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "xml", "json", "jsonc", "yaml", "html", "css", "javascript", "typescript" },
	callback = function(args)
		local bo = vim.bo[args.buf]
		bo.tabstop = 2
		bo.shiftwidth = 2
		bo.expandtab = true
	end,
})

vim.filetype.add({
	extension = {
		csproj = "xml",
		fsproj = "xml",
		vbproj = "xml",
		vcxproj = "xml",
		props = "xml",
		targets = "xml",
		nuspec = "xml",
		resx = "xml",
		slnx = "xml",
		ruleset = "xml",
		csx = "cs",
		cake = "cs",
		razor = "razor",
		cshtml = "razor",
		http = "http",
	},
	filename = {
		["Directory.Build.props"] = "xml",
		["Directory.Build.targets"] = "xml",
		["Directory.Packages.props"] = "xml",
		["nuget.config"] = "xml",
		["NuGet.config"] = "xml",
		["NuGet.Config"] = "xml",
		["packages.config"] = "xml",
		["app.config"] = "xml",
		["web.config"] = "xml",
		["global.json"] = "jsonc",
		["launchSettings.json"] = "jsonc",
		["appsettings.json"] = "jsonc",
	},
	pattern = {
		["appsettings%..*%.json"] = "jsonc",
	},
})

-- There is no Razor treesitter parser; HTML gets us usable highlighting.
vim.treesitter.language.register("html", "razor")
