local nixrun = require("nixrun")

local tests = {}
local n_ok = 0
local n_fail = 0

local function make_assert(name)
	return function(pred)
		assert(pred, 'in ' .. name)
	end
end

local function make_finish(name)
	return function(ok)
		tests[name] = nil
		if ok then
			n_ok = n_ok + 1
		else
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
---@param test fun(assert: fun(pred: boolean), fin: fun(ok: boolean))
local function do_test(name, test)
	tests[name] = true
	test(make_assert(name), make_finish(name))
end

do_test("add a plugin", function(assert, fin)
	local plug = "colortils-nvim"
	nixrun.add_plugin(plug, function(paths)
		assert(#paths == 1)
		assert(pcall(require, "colortils"))
		assert(nixrun.jobs()["plugins"][plug] == nil)
		fin(true)
	end, function()
		fin(false)
	end)

	assert(require("nixrun").jobs()["plugins"][plug])
end)

do_test("non-existent plugin fails", function(assert, fin)
	local plug = "fake-ass-plugin"
	nixrun.add_plugin(plug, function(_)
		fin(false)
	end, function(_)
		fin(true)
	end)

	assert(require("nixrun").jobs()["plugins"][plug])
end)
