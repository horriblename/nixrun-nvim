local nixrun = require("nixrun")

---@alias Finish fun(ok: boolean, err: string?)

local running = {}
local n_ok = 0
local n_fail = 0
-- Exclusives must be run after all non-exclusive ones cuz I'm lazy
---@type table<{name:string, test:fun(assert, finish)}>
local pending_exclusives = {}

local do_test

local function make_finish(name)
	return function(ok, err)
		if running[name] == nil then
			print("WARN finish called twice for: " .. name .. "\n")
			return
		end
		running[name] = nil

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

		if next(running) == nil and next(pending_exclusives) then
			local key, test = next(pending_exclusives)
			if key and test then
				pending_exclusives[key] = nil
				do_test(test.name, test.test)
			end
		end

		if next(running) == nil then
			print("OK:", n_ok, "Fail:", n_fail, "\n")
			if n_fail > 0 then
				os.exit(1)
			end
			os.exit(0)
		end
	end
end

local function make_assert(name)
	return function(pred)
		if not pred then
			-- ensure test exits (shut up I know it's bad)
			make_finish(name)(false, debug.traceback('failed assertion in test "' .. name .. '"'))
			error("failed assertion")
		end
	end
end
---@param name string
---@param test fun(assert: fun(pred: boolean), fin: Finish)
function do_test(name, test)
	running[name] = true
	local ok, err = pcall(test, make_assert(name), make_finish(name))
	if not ok then
		make_finish(name)(false, err)
	end
end

local function exclusive_test(name, test)
	if not next(running) then
		do_test(name, test)
	else
		table.insert(pending_exclusives, { name = name, test = test })
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

exclusive_test("select from nix-locate results", function(assert, fin)
	-- always chooses "toybox.out"
	vim.ui.select = function(items, _, on_choice)
		for _, item in ipairs(items) do
			if item == "toybox.out" then
				on_choice(item)
				return
			end
		end
		if items and items[1] then
			on_choice(items[1])
		end
	end

	local lsp = "fake-ls"
	local cmd = "printf"
	vim.lsp.config(lsp, {
		cmd = { cmd }
	})

	nixrun.add_lsp(lsp, function(err)
		if err then
			fin(false, err)
			return
		end
		assert(vim.fn.executable(cmd))
		fin(true)
	end)

	--- add_lsp doesn't call add_to_environment() immediately when nix-locate
	--- code path is used (waits for result from nix-locate) so it's not added
	--- to jobs() just yet (possibly a design flaw)
	-- assert(require("nixrun").jobs()["lsp"][lsp])
end)
