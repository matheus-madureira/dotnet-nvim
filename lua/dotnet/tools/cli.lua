-- A thin wrapper over the `dotnet` CLI. Non-interactive commands (build, test,
-- restore) run asynchronously and land in the quickfix list through an MSBuild
-- errorformat, so compiler errors are navigable with `:cnext`. Interactive ones
-- (run, watch) get a terminal split instead, because they want stdin and never
-- terminate on their own.
local M = {}

local project = require("dotnet.tools.project")

-- MSBuild: `Program.cs(12,9): error CS0103: message [C:\path\App.csproj]`
local MSBUILD_ERRORFORMAT = table.concat({
	[[%f(%l\,%c): %trror %.%#: %m]],
	[[%f(%l\,%c): %tarning %.%#: %m]],
	[[%f(%l): %trror %.%#: %m]],
	[[%f(%l): %tarning %.%#: %m]],
	[[%-G%.%#]],
}, ",")

local function configuration()
	return vim.g.dotnet_configuration or "Debug"
end

local function split_args(input)
	local args = {}

	for arg in (input or ""):gmatch("%S+") do
		args[#args + 1] = arg
	end

	return args
end

--- MSBuild reports each diagnostic once per project pass and tags it with the
--- owning project. Collapse the repeats and drop the tag.
local function tidy_quickfix(title)
	local seen = {}
	local items = {}

	for _, entry in ipairs(vim.fn.getqflist()) do
		entry.text = entry.text:gsub("%s*%[[^%]]*%.%a-proj%]%s*$", "")

		local key = table.concat({
			entry.bufnr,
			entry.lnum,
			entry.col,
			entry.type,
			entry.text,
		}, ":")

		if not seen[key] then
			seen[key] = true
			items[#items + 1] = entry
		end
	end

	vim.fn.setqflist({}, "r", { title = title, items = items })

	return #items
end

local function target_or_notify()
	local target = project.build_target()

	if not target then
		vim.notify("No .sln or .csproj found above the current file", vim.log.levels.WARN)
	end

	return target
end

-----------------------------------------------------------------------
-- Async commands -> quickfix
-----------------------------------------------------------------------

local running = nil

--- Run `dotnet <args>` in the background and route its output to quickfix.
function M.run_async(args, opts)
	opts = opts or {}

	if running then
		vim.notify("A dotnet command is already running", vim.log.levels.WARN)
		return
	end

	local label = opts.label or args[1] or "dotnet"
	local cwd = opts.cwd or project.root()

	vim.notify(("dotnet %s..."):format(label), vim.log.levels.INFO)
	running = label

	vim.system(vim.list_extend({ "dotnet" }, args), { cwd = cwd, text = true }, function(result)
		vim.schedule(function()
			running = nil

			local output = (result.stdout or "") .. (result.stderr or "")
			local lines = vim.split(output, "\n", { trimempty = true })

			vim.fn.setqflist({}, " ", {
				title = "dotnet " .. label,
				lines = lines,
				efm = MSBUILD_ERRORFORMAT,
			})

			local count = tidy_quickfix("dotnet " .. label)

			if result.code == 0 then
				vim.notify(("dotnet %s succeeded"):format(label), vim.log.levels.INFO)

				if count == 0 then
					vim.cmd("cclose")
				end
			else
				vim.notify(("dotnet %s failed (exit %d)"):format(label, result.code), vim.log.levels.ERROR)

				if count == 0 then
					-- Nothing matched the errorformat: show the raw output
					-- rather than silently swallowing the failure.
					vim.fn.setqflist({}, "r", { title = "dotnet " .. label, lines = lines })
				end

				vim.cmd("copen")
			end
		end)
	end)
end

-----------------------------------------------------------------------
-- Interactive commands -> terminal split
-----------------------------------------------------------------------

--- Open a terminal split running `dotnet <args>`.
function M.run_terminal(args, opts)
	opts = opts or {}

	local cwd = opts.cwd or project.root()
	local command = vim.list_extend({ "dotnet" }, args)

	vim.cmd("botright new")
	vim.api.nvim_win_set_height(0, opts.height or 15)

	vim.fn.jobstart(command, {
		cwd = cwd,
		term = true,
	})

	vim.cmd("startinsert")
end

-----------------------------------------------------------------------
-- Commands
-----------------------------------------------------------------------

function M.setup()
	local function command(name, fn, desc)
		vim.api.nvim_create_user_command(name, fn, { nargs = "*", desc = desc })
	end

	command("Build", function(args)
		local target = target_or_notify()
		if not target then
			return
		end

		M.run_async(
			vim.list_extend({ "build", target, "-c", configuration(), "--nologo" }, split_args(args.args)),
			{ label = "build" }
		)
	end, "dotnet build the solution or project")

	command("Rebuild", function(args)
		local target = target_or_notify()
		if not target then
			return
		end

		M.run_async(
			vim.list_extend(
				{ "build", target, "-c", configuration(), "--no-incremental", "--nologo" },
				split_args(args.args)
			),
			{ label = "rebuild" }
		)
	end, "dotnet build with --no-incremental")

	command("Restore", function(args)
		local target = target_or_notify()
		if not target then
			return
		end

		M.run_async(vim.list_extend({ "restore", target }, split_args(args.args)), { label = "restore" })
	end, "dotnet restore")

	command("Clean", function(args)
		local target = target_or_notify()
		if not target then
			return
		end

		M.run_async(
			vim.list_extend({ "clean", target, "-c", configuration() }, split_args(args.args)),
			{ label = "clean" }
		)
	end, "dotnet clean")

	command("Test", function(args)
		local target = target_or_notify()
		if not target then
			return
		end

		M.run_async(
			vim.list_extend({ "test", target, "-c", configuration(), "--nologo" }, split_args(args.args)),
			{ label = "test" }
		)
	end, "dotnet test")

	command("Publish", function(args)
		local target = target_or_notify()
		if not target then
			return
		end

		M.run_async(
			vim.list_extend({ "publish", target, "-c", "Release", "--nologo" }, split_args(args.args)),
			{ label = "publish" }
		)
	end, "dotnet publish in Release")

	command("DotnetFormat", function(args)
		local target = target_or_notify()
		if not target then
			return
		end

		M.run_async(vim.list_extend({ "format", target }, split_args(args.args)), { label = "format" })
	end, "dotnet format the solution or project")

	command("Run", function(args)
		local csproj = project.find_csproj()
		if not csproj then
			vim.notify("No .csproj found above the current file", vim.log.levels.WARN)
			return
		end

		M.run_terminal(
			vim.list_extend({ "run", "--project", csproj, "-c", configuration() }, split_args(args.args))
		)
	end, "dotnet run the owning project")

	command("Watch", function(args)
		local csproj = project.find_csproj()
		if not csproj then
			vim.notify("No .csproj found above the current file", vim.log.levels.WARN)
			return
		end

		M.run_terminal(vim.list_extend({ "watch", "--project", csproj }, split_args(args.args)))
	end, "dotnet watch the owning project")

	-----------------------------------------------------------------------
	-- Keymaps
	-----------------------------------------------------------------------

	local keymap = vim.keymap
	keymap.set("n", "<leader>bb", "<cmd>Build<CR>", { desc = "dotnet build" })
	keymap.set("n", "<leader>bB", "<cmd>Rebuild<CR>", { desc = "dotnet build --no-incremental" })
	keymap.set("n", "<leader>br", "<cmd>Run<CR>", { desc = "dotnet run" })
	keymap.set("n", "<leader>bw", "<cmd>Watch<CR>", { desc = "dotnet watch" })
	keymap.set("n", "<leader>bt", "<cmd>Test<CR>", { desc = "dotnet test" })
	keymap.set("n", "<leader>bR", "<cmd>Restore<CR>", { desc = "dotnet restore" })
	keymap.set("n", "<leader>bc", "<cmd>Clean<CR>", { desc = "dotnet clean" })
	keymap.set("n", "<leader>bf", "<cmd>DotnetFormat<CR>", { desc = "dotnet format" })
	keymap.set("n", "<leader>bp", "<cmd>Publish<CR>", { desc = "dotnet publish" })
end

return M
