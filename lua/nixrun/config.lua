local M = {}

---@class NixrunConfig
---@field nixpkgs string registry/url of nixpkgs, e.g. "flake:nixpkgs", "/home/user/nixpkgs", "channel:nixos-21.05"
M.default_config = {
	nixpkgs = "nixpkgs"
}
