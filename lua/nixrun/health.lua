local M = {}

local function is_list_of(xs, el_type)
	if not vim.islist(xs) then
		return false
	end

	for _, x in ipairs(xs) do
		if type(x) ~= el_type then
			return false
		end
	end
	return true
end

M.check = function()
	vim.health.start("Checking user config")

	-- NOTE: does not check default fields
	local cfg = require("nixrun.config")._config
	local schema = {
		nixpkgs = "string",
		lsp_overrides = "table",
		nix_build_flags = function(xs)
			return is_list_of(xs, "string")
		end,
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
