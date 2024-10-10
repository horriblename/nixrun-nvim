local M = {}

M.get_default_config = function()
	return require('nixrun.config').default_config
end

---@param options NixrunConfig
function M.setup(options)
	_G.nixrun_config = vim.tbl_deep_extend(_G.nixrun_config, options)
end

return M
