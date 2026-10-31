local M = {}

---@class NixrunConfig
---@field nixpkgs string registry/url of nixpkgs, e.g. "flake:nixpkgs", "/home/user/nixpkgs", "channel:nixos-21.05"
M.default_config = {
	nixpkgs = "nixpkgs"
}

M.config = setmetatable({}, {
	__index = function(_, key)
		return M.default_config[key]
	end
})

M.update = function(new)
	for k, v in pairs(new or {}) do
		M.config[k] = v
	end
end

return M
