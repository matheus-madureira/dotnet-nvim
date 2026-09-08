-- nvim-treesitter `main`: parsers are installed imperatively and highlighting is
-- started per buffer with `vim.treesitter.start()`. There is no `configs.setup()`
-- and no `ensure_installed` option any more.
local PARSERS = {
	"c_sharp",
	"xml", -- .csproj, Directory.Build.props, .targets
	"json", -- also drives jsonc: appsettings.json, global.json
	"yaml",
	"toml",
	"sql",
	"html", -- also drives .razor / .cshtml
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
}

--- Parsers are compiled on install. Without a toolchain nvim-treesitter errors
--- out on startup, so install nothing and say why once.
local function has_c_compiler()
	for _, compiler in ipairs({ "cc", "gcc", "clang", "cl", "zig" }) do
		if vim.fn.executable(compiler) == 1 then
			return true
		end
	end

	return false
end

--- The tree-sitter CLI compiles parsers through Rust's `cc` crate, which on
--- Windows prefers MSVC. A Visual Studio install without the C++ workload is
--- still detected but has no headers, so every parser dies on
--- `Cannot open include file: 'stdbool.h'`. Naming a compiler explicitly wins
--- that argument. A `CC` the user already set is left alone.
local function prefer_gcc_on_windows()
	if vim.fn.has("win32") == 0 or (vim.env.CC and vim.env.CC ~= "") then
		return
	end

	for _, compiler in ipairs({ "gcc", "clang" }) do
		if vim.fn.executable(compiler) == 1 then
			vim.env.CC = compiler
			return
		end
	end
end

-----------------------------------------------------------------------
-- Incremental selection
--
-- `main` dropped the module that used to provide this, so it lives here.
-- The stack holds the nodes selected so far, newest last.
-----------------------------------------------------------------------

local selection = {}

local ESC = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)

local function select_node(node)
	local start_row, start_col, end_row, end_col = node:range()

	-- `range()` gives an exclusive end column; a node ending at column 0 really
	-- ends at the last character of the previous line.
	if end_col == 0 then
		end_row = end_row - 1
		local line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1] or ""
		end_col = #line
	end

	-- Leave any active selection first, otherwise the `v` below would toggle
	-- visual mode off instead of starting a fresh selection.
	-- `string.char(22)` is CTRL-V, i.e. visual block.
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == string.char(22) then
		vim.cmd("normal! " .. ESC)
	end

	-- Enter visual mode at the node's start and extend to its end. `gv` cannot
	-- do this: on a buffer that has never been selected there is nothing to
	-- reselect, and the marks it reads are still unset.
	vim.fn.setpos(".", { 0, start_row + 1, start_col + 1, 0 })
	vim.cmd("normal! v")
	vim.fn.setpos(".", { 0, end_row + 1, math.max(end_col, 1), 0 })
end

local function init_selection()
	local ok, node = pcall(vim.treesitter.get_node)
	if not ok or not node then
		return
	end

	selection[vim.api.nvim_get_current_buf()] = { node }
	select_node(node)
end

local function node_incremental()
	local bufnr = vim.api.nvim_get_current_buf()
	local stack = selection[bufnr]

	if not stack or #stack == 0 then
		init_selection()
		return
	end

	local node = stack[#stack]

	-- Walk up until the range actually grows; wrapper nodes with an identical
	-- range would otherwise need several presses to do anything visible.
	local parent = node:parent()
	while parent and vim.deep_equal({ parent:range() }, { node:range() }) do
		parent = parent:parent()
	end

	if not parent then
		select_node(node)
		return
	end

	stack[#stack + 1] = parent
	select_node(parent)
end

local function node_decremental()
	local bufnr = vim.api.nvim_get_current_buf()
	local stack = selection[bufnr]

	if not stack or #stack < 2 then
		return
	end

	table.remove(stack)
	select_node(stack[#stack])
end

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
	group = vim.api.nvim_create_augroup("DotnetTreesitterSelection", { clear = true }),
	callback = function(args)
		selection[args.buf] = nil
	end,
})

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	dependencies = {
		{ "windwp/nvim-ts-autotag", opts = {} },
	},
	config = function()
		-- The jsonc filetype has no parser of its own; JSON's is close enough
		-- and is what appsettings.json / global.json need.
		vim.treesitter.language.register("json", "jsonc")

		prefer_gcc_on_windows()

		if not has_c_compiler() then
			vim.schedule(function()
				vim.notify(
					"Treesitter parsers need a C compiler. On Windows: "
						.. "`winget install --id=BrechtSanders.WinLibs.POSIX.UCRT -e`. "
						.. "Elsewhere install `gcc` or `clang`. Then run `:TSUpdate`.",
					vim.log.levels.WARN
				)
			end)
		elseif vim.fn.executable("tree-sitter") == 1 then
			-- Asynchronous, and a no-op for parsers that are already present.
			require("nvim-treesitter").install(PARSERS)
		else
			-- On a fresh machine Mason is still downloading the tree-sitter CLI
			-- while this runs, and every parser build would fail with ENOENT.
			-- Wait for Mason to report in, then install.
			vim.api.nvim_create_autocmd("User", {
				pattern = "MasonToolsUpdateCompleted",
				once = true,
				callback = function()
					vim.schedule(function()
						if vim.fn.executable("tree-sitter") == 1 then
							require("nvim-treesitter").install(PARSERS)
						else
							vim.notify(
								"nvim-treesitter needs the `tree-sitter` CLI. Install it with "
									.. "`:MasonInstall tree-sitter-cli`, then run `:TSUpdate`.",
								vim.log.levels.WARN
							)
						end
					end)
				end,
			})
		end

		-- Highlighting is opt-in per buffer on this branch. Collect every
		-- filetype these parsers serve, including the ones registered above
		-- and in core/options.lua (razor -> html).
		local filetypes = {}
		for _, parser in ipairs(PARSERS) do
			vim.list_extend(filetypes, vim.treesitter.language.get_filetypes(parser))
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("DotnetTreesitter", { clear = true }),
			pattern = filetypes,
			callback = function(args)
				-- Fails while a parser is still installing; harmless, the next
				-- buffer of that filetype picks it up.
				pcall(vim.treesitter.start, args.buf)
			end,
		})

		-- Treesitter indent is opt-in on this branch, and it fights the C#
		-- brace style, so it stays off: the LSP formatter owns indentation.

		local keymap = vim.keymap
		keymap.set("n", "<C-space>", init_selection, { desc = "Start incremental selection" })
		keymap.set("x", "<C-space>", node_incremental, { desc = "Grow selection to parent node" })
		keymap.set("x", "<BS>", node_decremental, { desc = "Shrink selection to child node" })
	end,
}
