-- Fills a freshly created .cs file with the namespace its folder implies and a
-- type stub named after the file -- the part an empty buffer never gets right.
local M = {}

local project = require("dotnet.tools.project")

--- Guess the declaration kind from the file name, the way the C# ecosystem
--- names things: IThing -> interface, ThingTests -> test class, and so on.
local function infer_kind(name)
	if name:match("^I%u") then
		return "interface"
	end

	if name:match("Tests?$") or name:match("^Test%u") then
		return "tests"
	end

	if name:match("Exception$") then
		return "exception"
	end

	if name:match("Attribute$") then
		return "attribute"
	end

	if name:match("Kind$") or name:match("Status$") then
		return "enum"
	end

	if name:match("Options$") or name:match("Settings$") then
		return "options"
	end

	if name:match("Dto$") or name:match("Request$") or name:match("Response$") then
		return "record"
	end

	return "class"
end

local function body_for(kind, name)
	if kind == "interface" then
		return { ("public interface %s"):format(name), "{", "", "}" }
	end

	if kind == "enum" then
		return { ("public enum %s"):format(name), "{", "", "}" }
	end

	if kind == "record" then
		return { ("public sealed record %s;"):format(name) }
	end

	if kind == "options" then
		local section = name:gsub("Options$", ""):gsub("Settings$", "")

		return {
			("public sealed class %s"):format(name),
			"{",
			('    public const string SectionName = "%s";'):format(section),
			"",
			"}",
		}
	end

	if kind == "exception" then
		return {
			("public sealed class %s : Exception"):format(name),
			"{",
			("    public %s(string message) : base(message)"):format(name),
			"    {",
			"    }",
			"",
			("    public %s(string message, Exception innerException)"):format(name),
			"        : base(message, innerException)",
			"    {",
			"    }",
			"}",
		}
	end

	if kind == "attribute" then
		return {
			"[AttributeUsage(AttributeTargets.Class)]",
			("public sealed class %s : Attribute"):format(name),
			"{",
			"",
			"}",
		}
	end

	if kind == "tests" then
		return {
			("public sealed class %s"):format(name),
			"{",
			"    [Fact]",
			"    public void Should()",
			"    {",
			"    }",
			"}",
		}
	end

	if kind == "static" then
		return { ("public static class %s"):format(name), "{", "", "}" }
	end

	return { ("public sealed class %s"):format(name), "{", "", "}" }
end

local function usings_for(kind)
	if kind == "tests" then
		return { "using Xunit;", "" }
	end

	return {}
end

--- Build the skeleton lines for a buffer, or nil when the file is not a plain
--- C# source file inside a project.
function M.build(bufnr, kind)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" or not path:match("%.cs$") then
		return nil
	end

	-- `Foo.Designer.cs` and `Foo.g.cs` belong to a generator, not to us.
	local file_name = vim.fn.fnamemodify(path, ":t")
	if select(2, file_name:gsub("%.", "")) > 1 then
		return nil
	end

	local name = vim.fn.fnamemodify(path, ":t:r")
	local namespace = project.namespace_for(path)
	if not namespace then
		return nil
	end

	kind = kind or infer_kind(name)

	local lines = {}
	vim.list_extend(lines, usings_for(kind))

	if vim.g.dotnet_file_scoped_namespaces == false then
		lines[#lines + 1] = ("namespace %s"):format(namespace)
		lines[#lines + 1] = "{"

		for _, line in ipairs(body_for(kind, name)) do
			lines[#lines + 1] = (line == "") and "" or ("    " .. line)
		end

		lines[#lines + 1] = "}"
	else
		lines[#lines + 1] = ("namespace %s;"):format(namespace)
		lines[#lines + 1] = ""
		vim.list_extend(lines, body_for(kind, name))
	end

	return lines
end

--- Insert the skeleton into the current buffer. Refuses to overwrite content.
function M.insert(kind)
	local bufnr = vim.api.nvim_get_current_buf()
	local existing = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	if #existing > 1 or (existing[1] or "") ~= "" then
		vim.notify("Skel: buffer is not empty", vim.log.levels.WARN)
		return
	end

	local lines = M.build(bufnr, kind)
	if not lines then
		vim.notify("Skel: not a C# file inside a project", vim.log.levels.WARN)
		return
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	-- Park the cursor on the blank line inside the type body.
	for i, line in ipairs(lines) do
		if line == "" and i > 1 and lines[i - 1]:match("{%s*$") then
			vim.api.nvim_win_set_cursor(0, { i, 0 })
			return
		end
	end
end

M.kinds = { "class", "static", "interface", "record", "enum", "options", "exception", "attribute", "tests" }

return M
