-- Loaded by LuaSnip's `from_lua` loader (see lua/dotnet/plugins/nvim-cmp.lua).
-- These cover the boilerplate the Roslyn server does not offer completions for.
local ls = require("luasnip")

local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local c = ls.choice_node
local f = ls.function_node
local fmt = require("luasnip.extras.fmt").fmt

--- Namespace implied by the file's folder, so snippets that need one agree with
--- the skeleton tool.
local function namespace()
	return require("dotnet.tools.project").namespace_for(vim.api.nvim_buf_get_name(0)) or "Namespace"
end

local function file_stem()
	local name = vim.fn.expand("%:t:r")
	return name ~= "" and name or "Type"
end

return {
	s(
		"ns",
		fmt("namespace {};\n\n{}", {
			f(namespace),
			i(0),
		})
	),

	s(
		"class",
		fmt(
			[[
public sealed class {}
{{
    {}
}}]],
			{
				i(1, file_stem()),
				i(0),
			}
		)
	),

	s(
		"prop",
		fmt("public {} {} {{ get; {}}}", {
			i(1, "string"),
			i(2, "Value"),
			c(3, { t("set; "), t("init; "), t("private set; "), t("") }),
		})
	),

	s(
		"ctor",
		fmt(
			[[
public {}({})
{{
    {}
}}]],
			{
				f(file_stem),
				i(1),
				i(0),
			}
		)
	),

	s(
		"asy",
		fmt(
			[[
public async Task<{}> {}Async({}, CancellationToken cancellationToken)
{{
    {}
}}]],
			{
				i(1, "Result"),
				i(2, "Do"),
				i(3),
				i(0),
			}
		)
	),

	s(
		"fact",
		fmt(
			[[
[Fact]
public void {}()
{{
    // Arrange
    {}

    // Act

    // Assert
}}]],
			{
				i(1, "Should_"),
				i(0),
			}
		)
	),

	s(
		"theory",
		fmt(
			[[
[Theory]
[InlineData({})]
public void {}({})
{{
    {}
}}]],
			{
				i(1),
				i(2, "Should_"),
				i(3),
				i(0),
			}
		)
	),

	s(
		"ctrl",
		fmt(
			[[
[ApiController]
[Route("api/[controller]")]
public sealed class {}Controller : ControllerBase
{{
    {}
}}]],
			{
				i(1, "Resource"),
				i(0),
			}
		)
	),

	s(
		"get",
		fmt(
			[[
[HttpGet("{}")]
public async Task<IActionResult> {}(CancellationToken cancellationToken)
{{
    {}
}}]],
			{
				i(1),
				i(2, "Get"),
				i(0),
			}
		)
	),

	s(
		"di",
		fmt("services.Add{}<{}, {}>();", {
			c(1, { t("Scoped"), t("Singleton"), t("Transient") }),
			i(2, "IService"),
			i(3, "Service"),
		})
	),

	s(
		"guard",
		fmt("ArgumentNullException.ThrowIfNull({});", {
			i(1, "argument"),
		})
	),

	s("region", {
		t("#region "),
		i(1, "Name"),
		t({ "", "", "" }),
		i(0),
		t({ "", "", "#endregion" }),
	}),
}
