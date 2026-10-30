local M = {}

M.get_default_config = function()
	return require("nixrun.config").default_config
end

---@param options NixrunConfig
function M.setup(options)
	_G.nixrun_config = vim.tbl_deep_extend("force", _G.nixrun_config or {}, options or {})
end

---@param installable string
---@param on_done fun(err: string?, paths: string[]?)? Function to run when done.
--- `paths` is the full path(s) to the installed packages
function M.add_plugin(installable, on_done)
	require("nixrun.lazy").includePlugin(installable, on_done)
end

---@param installable string
---@param on_done fun(err: string?, paths: string[]?)?
function M.add_grammar(installable, on_done)
	require("nixrun.lazy").includeGrammar(installable, on_done)
end

---@param name string
---@param on_done fun(err: string?)?
function M.add_lsp(name, on_done)
	require("nixrun.lazy").setupLsp(name, on_done)
end

---@param name string see |:NixRun-program|
---@param on_done fun(err: string?)?
function M.add_program(name, on_done)
	require("nixrun.lazy").includeProgram(name, on_done)
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
