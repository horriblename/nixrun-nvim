local M = {}

M.get_default_config = function()
	return require("nixrun.config").default_config
end

---@param options NixRun.Config
function M.setup(options)
	vim.validate("nixrun.setup()", options, "table", true)
	if options then
		require("nixrun.config").update(options)
	end
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

function M.cancel(...)
	return require("nixrun.lazy").cancel(...)
end

function M.cancel_all()
	return require("nixrun.lazy").cancel_all()
end

function M.status()
	return require("nixrun.lazy").status()
end

function M.job_status()
	return require("nixrun.lazy").job_status()
end

function M.print_status()
	return require("nixrun.lazy").print_status()
end

return M
