-- Shared project discovery: which .csproj owns a file, what namespace it should
-- get, where its build output lands. Every other tool in this directory builds
-- on top of this module.
local M = {}

local uv = vim.uv or vim.loop

local PROJECT_EXTENSIONS = { "csproj", "fsproj", "vbproj" }
local SOLUTION_EXTENSIONS = { "sln", "slnx" }

function M.normalize(path)
	-- gsub returns two values; the extra count must not leak to callers.
	return ((path or ""):gsub("\\", "/"))
end

local function is_file(path)
	local stat = path and uv.fs_stat(path)
	return (stat and stat.type == "file") or false
end

local function matches_extension(name, extensions)
	for _, ext in ipairs(extensions) do
		if name:match("%." .. ext .. "$") then
			return true
		end
	end

	return false
end

local function start_dir(path)
	if path and path ~= "" then
		return vim.fs.dirname(vim.fn.fnamemodify(path, ":p"))
	end

	local buffer_name = vim.api.nvim_buf_get_name(0)
	if buffer_name ~= "" then
		return vim.fs.dirname(vim.fn.fnamemodify(buffer_name, ":p"))
	end

	return vim.fn.getcwd()
end

local function find_upward(path, extensions)
	local found = vim.fs.find(function(name)
		return matches_extension(name, extensions)
	end, {
		path = start_dir(path),
		upward = true,
		type = "file",
		stop = uv.os_homedir(),
	})[1]

	return found and M.normalize(found) or nil
end

--- Nearest .csproj/.fsproj/.vbproj at or above `path`.
function M.find_csproj(path)
	return find_upward(path, PROJECT_EXTENSIONS)
end

--- Nearest .sln/.slnx at or above `path`.
function M.find_sln(path)
	return find_upward(path, SOLUTION_EXTENSIONS)
end

--- Directory holding the owning project file.
function M.project_dir(path)
	local csproj = M.find_csproj(path)
	return csproj and vim.fs.dirname(csproj) or nil
end

--- Workspace root: solution directory, else project directory, else git root.
function M.root(path)
	local sln = M.find_sln(path)
	if sln then
		return vim.fs.dirname(sln)
	end

	local project_dir = M.project_dir(path)
	if project_dir then
		return project_dir
	end

	local git_root = vim.fs.root(start_dir(path), { ".git" })
	return git_root and M.normalize(git_root) or vim.fn.getcwd()
end

--- The thing `dotnet build` should be pointed at: solution if there is one.
function M.build_target(path)
	return M.find_sln(path) or M.find_csproj(path)
end

local function read_property(csproj, property)
	if not is_file(csproj) then
		return nil
	end

	local ok, lines = pcall(vim.fn.readfile, csproj)
	if not ok then
		return nil
	end

	local pattern = "<" .. property .. ">%s*(.-)%s*</" .. property .. ">"
	for _, line in ipairs(lines) do
		local value = line:match(pattern)
		if value and value ~= "" and not value:match("^%$%(") then
			return value
		end
	end

	return nil
end

--- <RootNamespace>, falling back to <AssemblyName>, then the file stem.
function M.root_namespace(csproj)
	csproj = csproj or M.find_csproj()
	if not csproj then
		return nil
	end

	return read_property(csproj, "RootNamespace")
		or read_property(csproj, "AssemblyName")
		or vim.fn.fnamemodify(csproj, ":t:r")
end

--- <AssemblyName>, falling back to the project file stem.
function M.assembly_name(csproj)
	csproj = csproj or M.find_csproj()
	if not csproj then
		return nil
	end

	return read_property(csproj, "AssemblyName") or vim.fn.fnamemodify(csproj, ":t:r")
end

local function sanitize_segment(segment)
	local cleaned = segment:gsub("[^%w_]", "_")

	if cleaned:match("^%d") then
		cleaned = "_" .. cleaned
	end

	return cleaned
end

--- Namespace a file should declare: root namespace plus its folders, the way
--- `dotnet new` and the Roslyn "namespace does not match folder" analyzer expect.
function M.namespace_for(path)
	path = M.normalize(vim.fn.fnamemodify(path or vim.api.nvim_buf_get_name(0), ":p"))

	local csproj = M.find_csproj(path)
	if not csproj then
		return nil
	end

	local root_namespace = M.root_namespace(csproj)
	if not root_namespace then
		return nil
	end

	local relative = vim.fs.relpath(vim.fs.dirname(csproj), vim.fs.dirname(path))
	if not relative or relative == "." then
		return root_namespace
	end

	local segments = { root_namespace }
	for segment in M.normalize(relative):gmatch("[^/]+") do
		-- Convention: these folders never take part in the namespace.
		if segment ~= "." and segment ~= "bin" and segment ~= "obj" then
			segments[#segments + 1] = sanitize_segment(segment)
		end
	end

	return table.concat(segments, ".")
end

--- Newest build output for a project, e.g. bin/Debug/net9.0/Api.dll.
function M.find_dll(csproj, configuration)
	csproj = csproj or M.find_csproj()
	if not csproj then
		return nil
	end

	configuration = configuration or vim.g.dotnet_configuration or "Debug"

	local project_dir = vim.fs.dirname(csproj)
	local assembly = M.assembly_name(csproj)
	local patterns = {
		("%s/bin/%s/*/%s.dll"):format(project_dir, configuration, assembly),
		("%s/bin/%s/*/*/%s.dll"):format(project_dir, configuration, assembly),
	}

	local newest, newest_mtime = nil, -1
	for _, pattern in ipairs(patterns) do
		for _, candidate in ipairs(vim.fn.glob(pattern, false, true)) do
			local stat = uv.fs_stat(candidate)
			if stat and stat.mtime.sec > newest_mtime then
				newest, newest_mtime = M.normalize(candidate), stat.mtime.sec
			end
		end
	end

	return newest
end

return M
