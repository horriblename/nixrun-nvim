local M = {}

---@type nil|string[]
M._installable_parsers = nil

---@param nixExpr string
---@param succMsg string
---@param failMsg string
local function install_plugin(nixExpr, succMsg, failMsg)
	local cfg = require("nixrun").options
	local logs = {}

	vim.fn.jobstart(
		{ "nix", "build", "--print-out-paths", "--no-link", "--impure", "-I", string.format("nixpkgs=%s", cfg.nixpkgs),
			"--expr", nixExpr },
		{
			on_exit = function(_, exitcode, _)
				if exitcode ~= 0 then
					vim.notify(failMsg .. "\n" .. table.concat(logs, "\n"), vim.log.levels.ERROR)
				end
			end,
			on_stdout = function(_, data, _)
				vim.opt.runtimepath:prepend(data[1])
				vim.notify(succMsg)
			end,
			on_stderr = function(_, data, _)
				logs = data
			end,
			stdout_buffered = true,
			stderr_buffered = true,
		}
	)
end

---Installs the grammar asyncronously and add it to runtimepath upon completion
---@param name string
function M.includeGrammar(name)
	local expr = string.format(
		[[
		let
			pkgs = import <nixpkgs> {};
		in with pkgs;
			neovimUtils.grammarToPlugin vimPlugins.nvim-treesitter.builtGrammars.%s
		]],
		name
	)

	install_plugin(expr,
		string.format('Added grammar "%s" to runtimepath', name),
		'nix building grammar "' .. name .. '": '
	)
end

---@return string[]|nil
function M.listAvailableGrammars()
	if M._installable_parsers then
		return M._installable_parsers
	end

	local cmd = { "nix", "eval", "--json", "nixpkgs#vimPlugins.nvim-treesitter.builtGrammars", "--apply",
		"builtins.attrNames" }
	M._installable_parsers = vim.fn.json_decode(vim.fn.system(cmd))
	return M._installable_parsers
end

return M
