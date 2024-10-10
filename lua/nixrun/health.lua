local M = {}

M.check = function()
	vim.health.start("Checking user config")

	local cfg = vim.tbl_deep_extend(require('nixrun').default_config, _G.nixrun_config)
	local schema = {
		nixpkgs = { cfg.nixpkgs, "string" }
	}


	local ok, err = pcall(vim.validate, schema)
	if not ok then
		vim.health.error(err)
	else
		vim.health.ok("Config is valid")
	end
end

return M
