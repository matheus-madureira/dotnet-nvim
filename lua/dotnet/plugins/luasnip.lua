return {
	"L3MON4D3/LuaSnip",
	version = "v2.*",
	build = (vim.fn.executable("make") == 1) and "make install_jsregexp" or nil,
}
