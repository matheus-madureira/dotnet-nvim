-- Keeps namespaces honest when files move. Prefers the language server's
-- `workspace/willRenameFiles` edits (which also fix every reference), and falls
-- back to rewriting the declaration in the moved file itself.
local M = {}

local project = require("dotnet.tools.project")

local TYPE_KEYWORDS = {
	class = true,
	interface = true,
	record = true,
	struct = true,
	enum = true,
	delegate = true,
}

local function is_csharp_path(path)
	return path:match("%.cs$") ~= nil
end

--- True once we have reached the first type declaration: anything past it is
--- no longer the file-level namespace statement.
local function is_type_declaration(line)
	for word in line:gmatch("[%a_]+") do
		if TYPE_KEYWORDS[word] then
			return true
		end
	end

	return false
end

local function loaded_buf_for_file(path)
	local target = project.normalize(vim.fn.fnamemodify(path, ":p"))

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local name = vim.api.nvim_buf_get_name(bufnr)
			if name ~= "" and project.normalize(vim.fn.fnamemodify(name, ":p")) == target then
				return bufnr
			end
		end
	end

	return nil
end

--- Rewrite `namespace X` / `namespace X;` to the namespace the new location
--- implies. Returns true when a line actually changed.
local function rewrite_namespace(lines, namespace)
	for i, line in ipairs(lines) do
		local indent, current, terminator = line:match("^(%s*)namespace%s+([%w_%.]+)%s*([;{]?)%s*$")

		if current then
			if current == namespace then
				return false
			end

			lines[i] = ("%snamespace %s%s"):format(indent, namespace, terminator)
			return true
		end

		if is_type_declaration(line) then
			return false
		end
	end

	return false
end

local function apply_lsp_file_rename(old_abs, new_abs)
	local files = {
		{
			oldUri = vim.uri_from_fname(old_abs),
			newUri = vim.uri_from_fname(new_abs),
		},
	}

	local any_applied = false
	for _, client in ipairs(vim.lsp.get_clients()) do
		if client:supports_method("workspace/willRenameFiles") then
			local result = client:request_sync("workspace/willRenameFiles", { files = files }, 5000)
			local edit = result and result.result
			if edit then
				vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding or "utf-16")
				any_applied = true
			end
		end
	end

	return any_applied
end

--- Fix the namespace declaration of one file, on disk or in its loaded buffer.
--- Returns true when something was rewritten.
function M.fix_file(path)
	if not is_csharp_path(path) then
		return false
	end

	local namespace = project.namespace_for(path)
	if not namespace then
		return false
	end

	local bufnr = loaded_buf_for_file(path)
	local lines = bufnr and vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) or vim.fn.readfile(path)

	if not rewrite_namespace(lines, namespace) then
		return false
	end

	if bufnr then
		if not vim.bo[bufnr].modifiable then
			vim.notify("Skipped unmodifiable buffer: " .. path, vim.log.levels.WARN)
			return false
		end

		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	else
		vim.fn.writefile(lines, path)
	end

	return true
end

function M.on_node_renamed(data)
	local old_abs = data and data.old_name
	local new_abs = data and data.new_name

	if not old_abs or not new_abs then
		return
	end

	old_abs = project.normalize(old_abs)
	new_abs = project.normalize(new_abs)

	if not is_csharp_path(old_abs) or not is_csharp_path(new_abs) then
		return
	end

	if apply_lsp_file_rename(old_abs, new_abs) then
		vim.notify("Updated namespace and references via LSP file-rename edits", vim.log.levels.INFO)
		return
	end

	if M.fix_file(new_abs) then
		vim.notify("Updated namespace in " .. vim.fn.fnamemodify(new_abs, ":t"), vim.log.levels.INFO)
	end
end

function M.setup(api)
	if not api or not api.events or not api.events.subscribe or not api.events.Event then
		return
	end

	api.events.subscribe(api.events.Event.NodeRenamed, M.on_node_renamed)
end

return M
