-- Sorts and de-duplicates the leading `using` block of a C# file, following the
-- convention Visual Studio's "Remove and Sort Usings" applies: System first,
-- then everything else, ordinal, with each kind in its own group.
--
-- Put `// nousingformat` at the top of a file to opt out.
local M = {}

-----------------------------------------------------------------------
-- Parsing utilities
-----------------------------------------------------------------------

--- Classify one line of the using block.
--- Returns nil for anything that is not a using-ish directive.
local function parse_using(line)
	local extern = line:match("^%s*extern%s+alias%s+([%w_]+)%s*;%s*$")
	if extern then
		return { kind = "extern", name = extern, text = ("extern alias %s;"):format(extern) }
	end

	local body = line:match("^%s*global%s+using%s+(.-)%s*;%s*$")
	local is_global = body ~= nil

	if not body then
		body = line:match("^%s*using%s+(.-)%s*;%s*$")
	end

	if not body or body == "" then
		return nil
	end

	-- `using X = Some.Namespace.Type;` -- an alias, never `using (` statements.
	local alias, aliased = body:match("^([%w_]+)%s*=%s*(.+)$")
	if alias then
		return {
			kind = is_global and "global_alias" or "alias",
			name = alias,
			target = aliased,
			sort_key = alias,
		}
	end

	local static_target = body:match("^static%s+(.+)$")
	if static_target then
		return {
			kind = is_global and "global_static" or "static",
			name = static_target,
			sort_key = static_target,
		}
	end

	-- A namespace import must look like an identifier path; this rejects things
	-- such as `using var stream = ...;` that live inside method bodies.
	if not body:match("^[%w_%.]+$") then
		return nil
	end

	return {
		kind = is_global and "global" or "plain",
		name = body,
		sort_key = body,
	}
end

local function is_blank(line)
	return line:match("^%s*$") ~= nil
end

local function is_comment(line)
	return line:match("^%s*//") or line:match("^%s*/%*") or line:match("^%s*%*")
end

local function is_preprocessor(line)
	return line:match("^%s*#") ~= nil
end

local CONDITIONAL_DIRECTIVES = {
	["if"] = true,
	["else"] = true,
	["elif"] = true,
	["endif"] = true,
	["region"] = true,
	["endregion"] = true,
}

--- Directives that make reordering unsafe. `#nullable`, `#pragma`, `#define`
--- and friends are positional no-ops for the using block and are tolerated.
local function is_conditional_directive(line)
	local keyword = line:match("^%s*#%s*(%a+)")
	return keyword ~= nil and CONDITIONAL_DIRECTIVES[keyword] == true
end

local function has_nousingformat_marker(lines)
	for _, line in ipairs(lines) do
		if is_blank(line) then
			-- skip leading blank lines
		elseif line:match("^%s*//%s*nousingformat%s*$") then
			return true
		else
			return false
		end
	end

	return false
end

-----------------------------------------------------------------------
-- Using block detection
-----------------------------------------------------------------------

--- Find the contiguous run of using directives at the top of the file.
--- Bails out entirely when a preprocessor directive sits inside the block, or
--- when a conditional guards it: reordering across `#if` changes what compiles,
--- and a directive between two usings would be swallowed by the rewrite.
local function detect_using_block(lines)
	local start_idx, end_idx
	local items = {}
	local started = false

	for i = 1, #lines do
		local line = lines[i]

		if is_preprocessor(line) then
			-- Inside the block, any directive is unsafe to move across.
			if started or is_conditional_directive(line) then
				return nil
			end
		elseif not started then
			local using = parse_using(line)
			if using then
				started = true
				start_idx = i
				end_idx = i
				items[#items + 1] = using
			elseif not (is_blank(line) or is_comment(line)) then
				-- Real code before any using: nothing to sort.
				return nil
			end
		else
			local using = parse_using(line)
			if using then
				end_idx = i
				items[#items + 1] = using
			elseif is_blank(line) then
				end_idx = i
			else
				break
			end
		end
	end

	if not started then
		return nil
	end

	return {
		start_idx = start_idx,
		end_idx = end_idx,
		items = items,
	}
end

-----------------------------------------------------------------------
-- Formatting
-----------------------------------------------------------------------

local function is_system(name)
	return name == "System" or name:match("^System%.") ~= nil
end

--- System namespaces sort before everything else, then plain ordinal order.
local function compare(a, b)
	local a_system, b_system = is_system(a.sort_key), is_system(b.sort_key)

	if a_system ~= b_system then
		return a_system
	end

	return a.sort_key < b.sort_key
end

local function render(item)
	if item.kind == "extern" then
		return item.text
	end

	local prefix = item.kind:match("^global") and "global using " or "using "

	if item.kind == "alias" or item.kind == "global_alias" then
		return ("%s%s = %s;"):format(prefix, item.name, item.target)
	end

	if item.kind == "static" or item.kind == "global_static" then
		return ("%sstatic %s;"):format(prefix, item.name)
	end

	return ("%s%s;"):format(prefix, item.name)
end

local GROUP_ORDER = {
	"extern",
	"global",
	"global_static",
	"global_alias",
	"plain",
	"static",
	"alias",
}

local function format_block(items)
	local groups = {}
	local seen = {}

	for _, item in ipairs(items) do
		local key = item.kind .. "\0" .. (item.name or "") .. "\0" .. (item.target or "")

		if not seen[key] then
			seen[key] = true
			groups[item.kind] = groups[item.kind] or {}
			table.insert(groups[item.kind], item)
		end
	end

	local out = {}

	for _, kind in ipairs(GROUP_ORDER) do
		local group = groups[kind]

		if group and #group > 0 then
			if kind == "extern" then
				table.sort(group, function(a, b)
					return a.name < b.name
				end)
			else
				table.sort(group, compare)
			end

			-- Blank line between groups, never at the top.
			if #out > 0 then
				out[#out + 1] = ""
			end

			for _, item in ipairs(group) do
				out[#out + 1] = render(item)
			end
		end
	end

	return out
end

-----------------------------------------------------------------------
-- Entry point
-----------------------------------------------------------------------

function M.format(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) or not vim.bo[bufnr].modifiable then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	if has_nousingformat_marker(lines) then
		return
	end

	local block = detect_using_block(lines)
	if not block then
		return
	end

	local formatted = format_block(block.items)
	if #formatted == 0 then
		return
	end

	local after = lines[block.end_idx + 1]
	if after and not is_blank(after) then
		formatted[#formatted + 1] = ""
	end

	-- Nothing changed: leave the buffer (and its undo history) alone.
	local current = vim.list_slice(lines, block.start_idx, block.end_idx)
	if vim.deep_equal(current, formatted) then
		return
	end

	vim.api.nvim_buf_set_lines(bufnr, block.start_idx - 1, block.end_idx, false, formatted)
end

return M
