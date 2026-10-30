local M = {}

M.get_default_config = function()
	return require("nixrun.config").default_config
end

---@param options NixrunConfig
function M.setup(options)
	_G.nixrun_config = vim.tbl_deep_extend("force", _G.nixrun_config or {}, options or {})
end

---@param installable string
---@param on_done fun(paths: string[])? Function to run on success. `paths` is the full path(s) to the installed packages
---@param on_err fun(err: string)?
function M.add_plugin(installable, on_done, on_err)
	require("nixrun.lazy").includePlugin(installable, on_done, on_err)
end

---@param installable string
---@param on_done fun(paths: string[])? Function to run on success. `paths` is the full path(s) to the installed packages
---@param on_err fun(err: string)?
function M.add_grammar(installable, on_done, on_err)
	require("nixrun.lazy").includeGrammar(installable, on_done, on_err)
end

---@param name string
---@param on_done fun()? Function to run on success.
---@param on_err fun(err: string)?
function M.add_lsp(name, on_done, on_err)
	require("nixrun.lazy").setupLsp(name, on_done, on_err)
end

---@param name string see |:NixRun-program|
---@param on_done fun()?
---@param on_err fun(err: string)?
function M.add_program(name, on_done, on_err)
	require("nixrun.lazy").includeProgram(name, on_done, on_err)
end

function M.jobs()
	return require("nixrun.lazy").get_jobs()
end

function M.jobs_status()
	return require("nixrun.lazy").jobs_status()
end

function M.print_jobs()
	return require("nixrun.lazy").print_jobs()
end

return M
