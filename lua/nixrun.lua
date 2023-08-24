local M = {}

---@alias nixpkgsPath string

---@class NixrunConfig
---@field nixpkgs string registry/url of nixpkgs, e.g. "flake:nixpkgs", "/home/user/nixpkgs", "channel:nixos-21.05"

---@param options table
---@return NixrunConfig
local function with_defaults(options)
	-- TODO: warn unknown flags
	return {
		nixpkgs = "nixpkgs" or options.nixpkgs
	}
end

---@type NixrunConfig
M.options = with_defaults({})

---@param argLead string
---@return string[]
local function grammarCompletion(argLead, _, _)
	local grammars = require("nixrun.lazy").listAvailableGrammars()
	if argLead == '' then
		return grammars
	end
	return vim.fn.matchfuzzy(grammars, argLead)
end

---@param options NixrunConfig
function M.setup(options)
	M.options = with_defaults(options or {})

	vim.api.nvim_create_user_command(
		"NixRunTSGrammar",
		function(cmd_args)
			require("nixrun.lazy").includeGrammar(cmd_args.args)
		end,
		{
			complete = grammarCompletion,
			nargs = 1,
		}
	)
end

return M
