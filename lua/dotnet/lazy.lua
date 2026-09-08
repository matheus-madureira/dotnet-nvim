local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	{ import = "dotnet.plugins" },
	{ import = "dotnet.plugins.lsp" },
}, {
	change_detection = {
		notify = false,
	},
	-- neotest and nvim-nio ship rockspecs; without this lazy.nvim tries to
	-- bootstrap luarocks through hererocks on every install, which needs a
	-- toolchain none of these plugins actually require.
	rocks = {
		enabled = false,
	},
})

require("dotnet.core.theme").setup()
