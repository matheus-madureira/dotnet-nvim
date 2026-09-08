return {
	"mfussenegger/nvim-dap",
	dependencies = { "nvim-neotest/nvim-nio" },

	config = function()
		local dap = require("dap")
		local project = require("dotnet.tools.project")
		local uv = vim.uv or vim.loop

		-----------------------------------------------------------------------
		-- Adapter discovery: netcoredbg from PATH, else the Mason install
		-----------------------------------------------------------------------
		local function netcoredbg_path()
			local on_path = vim.fn.exepath("netcoredbg")
			if on_path ~= "" then
				return on_path
			end

			local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg"
			for _, candidate in ipairs({ mason_bin, mason_bin .. ".cmd", mason_bin .. ".exe" }) do
				if uv.fs_stat(candidate) then
					return candidate
				end
			end

			return nil
		end

		-- Resolved on first use rather than at startup: Mason may still be
		-- installing netcoredbg the first time this config is opened.
		local function coreclr_adapter(callback)
			local adapter = netcoredbg_path()

			if not adapter then
				vim.notify(
					"No .NET debug adapter found. Install it with `:MasonInstall netcoredbg`.",
					vim.log.levels.ERROR
				)
				return
			end

			callback({
				type = "executable",
				command = adapter,
				args = { "--interpreter=vscode" },
			})
		end

		dap.adapters.coreclr = coreclr_adapter
		-- `netcoredbg` is the type name used by launch.json files in the wild.
		dap.adapters.netcoredbg = coreclr_adapter

		-----------------------------------------------------------------------
		-- Target selection
		-----------------------------------------------------------------------
		local function build_project(csproj)
			vim.notify("Building " .. vim.fn.fnamemodify(csproj, ":t") .. "...", vim.log.levels.INFO)

			local output = vim.fn.system({
				"dotnet",
				"build",
				csproj,
				"-c",
				vim.g.dotnet_configuration or "Debug",
				"--nologo",
				"-v",
				"quiet",
			})

			if vim.v.shell_error ~= 0 then
				vim.notify("Build failed:\n" .. output, vim.log.levels.ERROR)
				return false
			end

			return true
		end

		--- Resolve the DLL to debug: build the owning project, then find its output.
		local function pick_dll()
			local csproj = project.find_csproj()

			if csproj then
				if not build_project(csproj) then
					return dap.ABORT
				end

				local dll = project.find_dll(csproj)
				if dll then
					vim.notify("Debugging " .. dll, vim.log.levels.INFO)
					return dll
				end

				vim.notify(
					("No %s output found for %s"):format(
						vim.g.dotnet_configuration or "Debug",
						vim.fn.fnamemodify(csproj, ":t")
					),
					vim.log.levels.WARN
				)
			end

			local picked = vim.fn.input("Path to dll: ", project.root() .. "/", "file")
			if picked == "" then
				vim.notify("DAP launch cancelled: no assembly selected", vim.log.levels.WARN)
				return dap.ABORT
			end

			if not uv.fs_stat(picked) then
				vim.notify("DAP launch aborted: file not found: " .. picked, vim.log.levels.ERROR)
				return dap.ABORT
			end

			return picked
		end

		local function split_args(input)
			local args = {}
			for arg in string.gmatch(input, "%S+") do
				table.insert(args, arg)
			end
			return args
		end

		local function prompt_args()
			return split_args(vim.fn.input("Program arguments: "))
		end

		local dotnet_env = {
			DOTNET_ENVIRONMENT = "Development",
			ASPNETCORE_ENVIRONMENT = "Development",
		}

		-----------------------------------------------------------------------
		-- Debug configurations for C#, F#, VB
		-----------------------------------------------------------------------
		local dotnet_configurations = {
			{
				name = "Launch",
				type = "coreclr",
				request = "launch",
				program = pick_dll,
				cwd = "${workspaceFolder}",
				stopAtEntry = false,
				env = dotnet_env,
			},
			{
				name = "Launch with args",
				type = "coreclr",
				request = "launch",
				program = pick_dll,
				args = prompt_args,
				cwd = "${workspaceFolder}",
				stopAtEntry = false,
				env = dotnet_env,
			},
			{
				name = "Launch (stop at entry)",
				type = "coreclr",
				request = "launch",
				program = pick_dll,
				cwd = "${workspaceFolder}",
				stopAtEntry = true,
				env = dotnet_env,
			},
			{
				name = "Attach to process",
				type = "coreclr",
				request = "attach",
				processId = require("dap.utils").pick_process,
				cwd = "${workspaceFolder}",
			},
		}

		dap.configurations.cs = dotnet_configurations
		dap.configurations.fsharp = dotnet_configurations
		dap.configurations.vb = dotnet_configurations
		dap.configurations.razor = dotnet_configurations

		-----------------------------------------------------------------------
		-- Breakpoint signs
		-----------------------------------------------------------------------
		vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DiagnosticError" })
		vim.fn.sign_define("DapBreakpointCondition", { text = "", texthl = "DiagnosticWarn" })
		vim.fn.sign_define("DapLogPoint", { text = "", texthl = "DiagnosticInfo" })
		vim.fn.sign_define("DapStopped", { text = "", texthl = "DiagnosticOk", linehl = "Visual" })

		-----------------------------------------------------------------------
		-- Keybindings
		-----------------------------------------------------------------------
		vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Continue" })
		vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Breakpoint" })
		vim.keymap.set("n", "<leader>dB", function()
			dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
		end, { desc = "Conditional breakpoint" })
		vim.keymap.set("n", "<leader>ds", dap.step_over, { desc = "Step Over" })
		vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Step Into" })
		vim.keymap.set("n", "<leader>do", dap.step_out, { desc = "Step Out" })
		vim.keymap.set("n", "<leader>dr", dap.restart, { desc = "Restart" })
		vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = "Terminate" })
		vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Run last configuration" })
	end,
}
