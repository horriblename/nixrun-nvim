local M = {}

---@class NixRun.Config
---@field nixpkgs string registry/url of nixpkgs, e.g. "flake:nixpkgs", "/home/user/nixpkgs", "channel:nixos-21.05"
---@field lsp_overrides table<string, string> maps LSPs to their installable
M.default_config = {
	nixpkgs = "nixpkgs",
	lsp_overrides = {},
}

---@type NixRun.Config
M._config = vim.deepcopy(M.default_config)

---@param root string where in the root table we're at, e.g. foo.bar
---@param tbl table<string, any> table to update
---@param new table<string, any> values to change
local function deep_update(root, tbl, new)
	assert(type(tbl) == "table")
	assert(type(new) == "table")

	for k, v in pairs(new or {}) do
		if type(v) == "table" and not vim.islist(tbl) then
			---@cast v table
			local path = root == "" and k or root .. "." .. k
			if tbl[k] ~= nil and type(tbl[k]) ~= "table" then
				error(path .. ": should not be a table")
			end
			if tbl[k] == nil then
				tbl[k] = {}
			end
			deep_update(path, tbl[k], v)
		else
			tbl[k] = v
		end
	end
end

M.update = function(new)
	deep_update("", M._config, new)
end

return M
