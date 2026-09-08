local M = {}

--- True when saving this buffer will hand the using block to the language
--- server: a formatting-capable client is attached, format-on-save is on, and
--- the server -- not CSharpier -- is the one doing it.
local function lsp_organizes_usings(bufnr)
	if vim.g.dotnet_formatter == "csharpier" then
		return false
	end

	if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
		return false
	end

	return #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/formatting" }) > 0
end

function M.setup()
	local group = vim.api.nvim_create_augroup("DotnetTools", { clear = true })

	-- Sort and de-duplicate the using block on save -- unless the language server
	-- is about to do it anyway. With `dotnet_organize_imports_on_format` the
	-- format-on-save pass rewrites the whole block straight from the
	-- `.editorconfig`, so running both means the second one undoes the first.
	vim.api.nvim_create_autocmd("BufWritePre", {
		group = group,
		pattern = { "*.cs", "*.csx" },
		callback = function(args)
			if lsp_organizes_usings(args.buf) then
				return
			end

			require("dotnet.tools.usings_formatter").format(args.buf)
		end,
	})

	-- Seed new C# files with namespace + type stub.
	vim.api.nvim_create_autocmd("BufNewFile", {
		group = group,
		pattern = "*.cs",
		callback = function(args)
			if vim.g.dotnet_skeleton_on_new == false then
				return
			end

			local lines = require("dotnet.tools.skeleton").build(args.buf)
			if lines then
				vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, lines)
			end
		end,
	})

	-- :Skel [kind] -- insert a skeleton into the current (empty) buffer
	vim.api.nvim_create_user_command("Skel", function(opts)
		require("dotnet.tools.skeleton").insert(opts.args ~= "" and opts.args or nil)
	end, {
		nargs = "?",
		complete = function(arg_lead)
			return vim.tbl_filter(function(kind)
				return kind:find(arg_lead, 1, true) == 1
			end, require("dotnet.tools.skeleton").kinds)
		end,
		desc = "Insert a C# type skeleton",
	})

	-- :NamespaceFix -- realign the current file's namespace with its folder
	vim.api.nvim_create_user_command("NamespaceFix", function()
		local path = vim.api.nvim_buf_get_name(0)

		if require("dotnet.tools.namespace_rename").fix_file(path) then
			vim.notify("Namespace updated", vim.log.levels.INFO)
		else
			vim.notify("Namespace already matches the folder layout", vim.log.levels.INFO)
		end
	end, { desc = "Align the namespace with the folder layout" })

	-- :UsingsSort -- run the using-block formatter on demand
	vim.api.nvim_create_user_command("UsingsSort", function()
		require("dotnet.tools.usings_formatter").format(0)
	end, { desc = "Sort and de-duplicate usings" })

	-- Style, naming and analyzer severities for C#: a default `.editorconfig`
	-- the language server and the formatter both read.
	require("dotnet.tools.editorconfig").setup(group)

	require("dotnet.tools.cli").setup()
end

return M
