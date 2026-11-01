local M = {}

M.check = function()
	vim.health.start("Checking user config")

	-- NOTE: does not check default fields
	local cfg = require("nixrun.config")._config
	local schema = {
		nixpkgs = "string",
		lsp_overrides = "table",
	}


	local valid = true
	for key, spec in pairs(schema) do
		local ok, err = pcall(vim.validate, key, cfg[key], spec)
		if not ok then
			vim.health.error(err --[[@as string]])
			valid = false
		end
	end

	if valid then
		vim.health.ok("Config is valid")
	end
end

return M
