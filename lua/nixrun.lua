local M = {}

M.get_default_config = function()
	return require('nixrun.config').default_config
end

---@param options NixrunConfig
function M.setup(options)
	_G.nixrun_config = vim.tbl_deep_extend('force', _G.nixrun_config or {}, options or {})
end

---@param installable string
---@param on_done fun(paths: string[])?
function M.add_plugin(installable, on_done)
	require('nixrun.lazy').includePlugin(installable, on_done)
end

---@param installable string
---@param on_done fun(paths: string[])?
function M.add_grammar(installable, on_done)
	require('nixrun.lazy').includeGrammar(installable, on_done)
end

---@param name string
---@param on_done fun()?
function M.add_lsp(name, on_done)
	require('nixrun.lazy').setupLsp(name, on_done)
end

return M
