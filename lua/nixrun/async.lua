-- Poor man's async/await. Will replace with vim.async once that comes out
--
-- Usage:
--
-- ```
-- local async = require("nixrun.async")
-- local await = async.await
-- async.spawn(function()
-- 	local status = await(function(cb)
--		vim.system({"curl", "https://wttr.in/?T&format=3"}, {text=true}, cb)
-- 	end)
--
-- 	vim.print(status.out)
-- end)
-- ```
--
-- Worth noting there are no "colored" functions.

local M = {}
local unpack = unpack or table.unpack
local pack = table.pack or function(...)
	return { n = select("#", ...), ... }
end

---Like await(), but protects against an error() before cb is called
---@generic Ret
---@param start fun(cb: fun(Ret, ...))
---@return boolean ok, Ret, ...
function M.pawait(start)
	local co = coroutine.running()
	local starting = true
	local pending = nil
	local called = false

	local function callback(...)
		if called then
			return
		end
		called = true

		if starting then
			pending = pack(...)
			return
		end

		local ok, err = coroutine.resume(co, ...)
		if not ok then
			vim.schedule(function()
				error(err)
			end)
		end
	end

	local ok, err = pcall(start, callback)
	starting = false

	if not ok then
		return false, err
	end

	if pending then
		return true, unpack(pending, 1, pending.n)
	end

	return true, coroutine.yield()
end

---@generic Ret
---@param start fun(cb: fun(Ret, ...))
---@return Ret, ...
function M.await(start)
	local ret = pack(M.pawait(start))
	if ret[1] then
		return unpack(ret, 2, ret.n)
	else
		error(ret[2])
	end
end

---@param fn function
---@return thread
function M.spawn(fn)
	local co = coroutine.create(fn)

	local ok, err = coroutine.resume(co)

	if not ok then
		error(err)
	end

	return co
end

---The following are equivalent:
---
---```
---local foo = wrap(function(arg, on_done)
---	body()
---end)
---
---local foo = function(arg, on_done)
---	spawn(function()
---		body()
---	end)
---end
---```
function M.wrap(fn)
	return function(...)
		local args = { ... }
		M.spawn(function()
			fn(unpack(args))
		end)
	end
end

return M
