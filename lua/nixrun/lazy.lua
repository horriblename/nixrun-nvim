local M = {}

---@type nil|string[]
M._installable_parsers = nil

---@param dir string
local function source_dir(dir)
	pcall(vim.cmd.source, dir .. '/**/*.vim')
	pcall(vim.cmd.source, dir .. '/**/*.lua')
end

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
				local path = data[1]
				if not vim.tbl_contains(vim.opt.runtimepath:get(), path) then
					vim.opt.runtimepath:prepend(path)
					-- mimics the behavior of :packadd
					source_dir(path .. '/plugin')
					-- XXX: I don't know if there's a better way to detect if ft detection is on
					if vim.fn.exists("#filetypedetect") == 1 then
						pcall(vim.cmd.source, path .. '/ftdetect/*.vim')
					end
					vim.notify(succMsg)
				end
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
	-- TODO: avoid impure
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

---@return string[]
function M.listAvailableGrammars()
	if M._installable_parsers then
		return M._installable_parsers
	end

	local cmd = { "nix", "eval", "--json", "nixpkgs#vimPlugins.nvim-treesitter.builtGrammars", "--apply",
		"builtins.attrNames" }
	M._installable_parsers = vim.fn.json_decode(vim.fn.system(cmd))
	return M._installable_parsers
end

---Installs the plugin from nixpkgs#vimPlugins."name" asyncronously and add it to runtimepath upon completion
---@param name string
function M.includePlugin(name)
	local expr = string.format(
		[[
		let
			pkgs = import <nixpkgs> {};
		in with pkgs;
			vimPlugins.%s
		]],
		name
	)

	install_plugin(expr,
		string.format('Added plugin "%s" to runtimepath', name),
		'nix building plugin "' .. name .. '": '
	)
end

---@return string[]
function M.listAvailablePlugins()
	if M._installable_plugins then
		return M._installable_plugins
	end

	local cmd = { "nix", "eval", "--json", "nixpkgs#vimPlugins", "--apply", "builtins.attrNames" }
	M._installable_plugins = vim.fn.json_decode(vim.fn.system(cmd))
	return M._installable_plugins
end

return M
