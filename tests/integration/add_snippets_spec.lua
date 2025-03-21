local helpers = require("test.functional.helpers")(after_each)
local exec_lua, feed, exec = helpers.exec_lua, helpers.feed, helpers.exec
local ls_helpers = require("helpers")
local Screen = require("test.functional.ui.screen")

describe("add_snippets", function()
	local screen

	before_each(function()
		helpers.clear()
		ls_helpers.session_setup_luasnip()

		screen = Screen.new(50, 3)
		screen:attach()
		screen:set_default_attr_ids({
			[0] = { bold = true, foreground = Screen.colors.Blue },
			[1] = { bold = true, foreground = Screen.colors.Brown },
			[2] = { bold = true },
			[3] = { background = Screen.colors.LightGray },
		})
	end)

	after_each(function()
		screen:detach()
	end)

	it("overrides previously loaded snippets with the same key", function()
		exec_lua([[
			ls.add_snippets("all", {
				ls.parser.parse_snippet("trigger1", "aaaaa")
			}, {
				key = "a"
			} )
		]])
		exec_lua([[
			ls.add_snippets("all", {
				ls.parser.parse_snippet("trigger2", "eeeee")
			}, {
				key = "a"
			} )
		]])

		feed("itrigger2")
		exec_lua("ls.expand()")
		-- snippets from second call expands.
		screen:expect({
			grid = [[
			eeeee^                                             |
			{0:~                                                 }|
			{2:-- INSERT --}                                      |]],
		})
		feed("<space>trigger1")
		exec_lua("ls.expand()")

		-- snippet from first call was removed.
		screen:expect({
			grid = [[
			eeeee trigger1^                                    |
			{0:~                                                 }|
			{2:-- INSERT --}                                      |]],
		})
	end)

	it("correctly loads autosnippets", function()
		exec_lua("ls.config.setup({ enable_autosnippets = true })")
		exec_lua([[
			ls.add_snippets("all", {
				ls.parser.parse_snippet("trigger1", "aaaaa")
			}, {
				type = "autosnippets"
			} )
		]])

		feed("itrigger1")
		screen:expect({
			grid = [[
			aaaaa^                                             |
			{0:~                                                 }|
			{2:-- INSERT --}                                      |]],
		})
	end)

	it("can handle snippet-table", function()
		exec_lua([[
			ls.add_snippets(nil, {
				all = {
					ls.parser.parse_snippet("trigger1", "aaaaa")
				},
				c = {
					ls.parser.parse_snippet("trigger2", "eeeee")
				}
			})
		]])

		feed("itrigger1")
		exec_lua("ls.expand()")
		screen:expect({
			grid = [[
			aaaaa^                                             |
			{0:~                                                 }|
			{2:-- INSERT --}                                      |]],
		})
		exec("set ft=c")
		feed("<space>trigger2")
		exec_lua("ls.expand()")
		screen:expect({
			grid = [[
			aaaaa eeeee^                                       |
			{0:~                                                 }|
			{2:-- INSERT --}                                      |]],
		})
	end)
end)
