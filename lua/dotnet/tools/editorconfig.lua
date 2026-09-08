-- The C# style and severity defaults this configuration ships with.
--
-- Roslyn (and OmniSharp) read code style, naming rules and analyzer severities
-- from `.editorconfig`; CSharpier and `dotnet format` read their whitespace
-- settings from the same file. No LSP setting or formatter flag reaches both,
-- so the only way to hand the two of them one shared ruleset is to put the file
-- in the workspace -- which is also what makes the rules survive outside Neovim
-- (CI, `dotnet build`, Visual Studio, a teammate).
--
-- Hence: `templates/dotnet.editorconfig` is the default, and this module copies
-- it into a workspace that has none. A project that already carries an
-- `.editorconfig` anywhere above the file is never touched -- its rules win.
local M = {}

local uv = vim.uv or vim.loop

local project = require("dotnet.tools.project")

local TEMPLATE = "templates/dotnet.editorconfig"

-- Roots already handled this session, so opening the tenth C# buffer of a
-- solution does not walk the tree again.
local seen = {}

local function is_file(path)
	local stat = path and uv.fs_stat(path)
	return (stat and stat.type == "file") or false
end

--- Absolute path of the bundled template, found through the runtimepath so the
--- config keeps working wherever it was cloned.
function M.template()
	local found = vim.api.nvim_get_runtime_file(TEMPLATE, false)[1]
	return found and project.normalize(found) or nil
end

local function buffer_dir(path)
	path = path or vim.api.nvim_buf_get_name(0)

	if path == "" or path:match("^%a[%w+.-]*://") then
		return nil
	end

	return vim.fs.dirname(vim.fn.fnamemodify(path, ":p"))
end

--- Nearest `.editorconfig` at or above `path`, or nil. Unlike the lookups in
--- project.lua this one runs to the filesystem root, because that is how the
--- EditorConfig spec resolves a file and we must not shadow one that applies.
function M.find(path)
	local dir = buffer_dir(path)
	if not dir then
		return nil
	end

	local found = vim.fs.find(".editorconfig", { path = dir, upward = true, type = "file" })[1]

	return found and project.normalize(found) or nil
end

--- Where a generated `.editorconfig` belongs: the solution directory, else the
--- project directory, else the git root. Returns nil when the buffer sits in
--- none of those -- a stray file under `$HOME` is not a workspace, and dropping
--- a ruleset next to it would apply it to everything below.
function M.root(path)
	local sln = project.find_sln(path)
	if sln then
		return vim.fs.dirname(sln)
	end

	local project_dir = project.project_dir(path)
	if project_dir then
		return project_dir
	end

	local dir = buffer_dir(path)
	local git_root = dir and vim.fs.root(dir, { ".git" })

	return git_root and project.normalize(git_root) or nil
end

--- Copy the template to `dir`. Returns the written path, or nil plus a reason.
function M.write(dir, opts)
	opts = opts or {}

	if not dir then
		return nil, "no workspace root here (open a file inside a solution, project or git repository)"
	end

	local target = project.normalize(dir) .. "/.editorconfig"

	if is_file(target) and not opts.force then
		return nil, target .. " already exists (use :DotnetEditorConfig! to overwrite)"
	end

	local template = M.template()
	if not template then
		return nil, "bundled " .. TEMPLATE .. " not found on the runtimepath"
	end

	local ok, lines = pcall(vim.fn.readfile, template)
	if not ok then
		return nil, "could not read " .. template
	end

	if vim.fn.writefile(lines, target) ~= 0 then
		return nil, "could not write " .. target
	end

	return target
end

--- The automatic half: give a workspace the defaults the first time one of its
--- C# buffers shows up without any `.editorconfig` of its own.
function M.ensure(path)
	if vim.g.dotnet_editorconfig == false then
		return
	end

	local root = M.root(path)
	if not root or seen[root] then
		return
	end

	seen[root] = true

	if M.find(path) then
		return
	end

	-- Silent on failure: a read-only checkout is not worth a message on every
	-- file opened in it.
	local target = M.write(root)
	if not target then
		return
	end

	vim.notify(
		("Wrote default C# ruleset to %s -- `:Roslyn restart` reapplies the severities.\nSet `vim.g.dotnet_editorconfig = false` to stop generating it.")
			:format(target),
		vim.log.levels.INFO
	)
end

function M.setup(group)
	-- Any door into a .NET workspace, not just C# buffers: opening the .sln is
	-- as good a moment as opening a class.
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = group,
		pattern = { "*.cs", "*.csx", "*.razor", "*.cshtml", "*.csproj", "*.sln", "*.slnx" },
		callback = function(args)
			M.ensure(vim.api.nvim_buf_get_name(args.buf))
		end,
	})

	-- :DotnetEditorConfig [dir] -- drop the defaults into a workspace on demand.
	-- With `!` it overwrites the file that is already there.
	vim.api.nvim_create_user_command("DotnetEditorConfig", function(opts)
		local dir = opts.args ~= "" and vim.fn.fnamemodify(opts.args, ":p") or M.root()

		local target, reason = M.write(dir, { force = opts.bang })
		if not target then
			vim.notify(reason, vim.log.levels.WARN)
			return
		end

		seen[project.normalize(dir)] = true
		vim.notify("Wrote default C# ruleset to " .. target, vim.log.levels.INFO)
	end, {
		bang = true,
		nargs = "?",
		complete = "dir",
		desc = "Write the default C# .editorconfig into the workspace",
	})

	-- :DotnetEditorConfigEdit -- open whichever ruleset is actually in effect,
	-- the project's copy or the bundled template.
	vim.api.nvim_create_user_command("DotnetEditorConfigEdit", function()
		local target = M.find() or M.template()

		if not target then
			vim.notify("No .editorconfig in effect and no bundled template found", vim.log.levels.WARN)
			return
		end

		vim.cmd.edit(vim.fn.fnameescape(target))
	end, { desc = "Open the C# .editorconfig in effect" })
end

return M
