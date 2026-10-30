local nixrun = require("nixrun")

---@alias Finish fun(ok: boolean, err: string?)

local tests = {}
local n_ok = 0
local n_fail = 0

local function make_assert(name)
	return function(pred)
		assert(pred, 'in ' .. name)
	end
end

local function make_finish(name)
	return function(ok, err)
		tests[name] = nil
		if ok then
			print("OK  ", name, "\n")
			n_ok = n_ok + 1
		else
			if err then
				print(err, "\n---\n")
			end
			print("FAIL", name, "\n")
			n_fail = n_fail + 1
		end
		if next(tests) == nil then
			print("OK:", n_ok, "Fail:", n_fail)
			if n_fail > 0 then
				os.exit(1)
			end
			os.exit(0)
		end
	end
end

---@param name string
---@param test fun(assert: fun(pred: boolean), fin: Finish)
function do_test(name, test)
	tests[name] = true
	local ok, err = pcall(test, make_assert(name), make_finish(name))
	if not ok then
		make_finish(name)(false, err)
	end
end

do_test("add a plugin", function(assert, fin)
	local plug = "colortils-nvim"
	nixrun.add_plugin(plug, function(err, paths)
		if err then
			fin(false, err)
			return
		end
		assert(#paths == 1)
		assert(pcall(require, "colortils"))
		assert(nixrun.jobs()["plugins"][plug] == nil)
		fin(true)
	end)

	assert(require("nixrun").jobs()["plugins"][plug])
end)

do_test("plugin from URL", function(assert, fin)
	local plug = "github:nvim-treesitter/nvim-treesitter"
	nixrun.add_plugin(plug, function(err, paths)
		if err then
			fin(false, err)
			return
		end
		assert(#paths == 1)
		assert(pcall(require, "nvim-treesitter"))
		assert(nixrun.jobs()["plugins"][plug] == nil)
		fin(true)
	end)

	assert(require("nixrun").jobs()["plugins"][plug])
end)

do_test("add plugin from full flake attribute", function(assert, fin)
	local plug = "github:nixos/nixpkgs#vimPlugins.colortils-nvim"
	nixrun.add_plugin(plug, function(err, paths)
		if err then
			fin(false, err)
			return
		end
		assert(#paths == 1)
		assert(pcall(require, "nvim-treesitter"))
		assert(nixrun.jobs()["plugins"][plug] == nil)
		fin(true)
	end)

	assert(require("nixrun").jobs()["plugins"][plug])
end)

do_test("non-existent plugin fails", function(assert, fin)
	local plug = "fake-ass-plugin"
	nixrun.add_plugin(plug, function(err)
		fin(err ~= nil, err)
	end)

	assert(require("nixrun").jobs()["plugins"][plug])
end)
