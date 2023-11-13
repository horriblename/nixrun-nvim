local M = {}

---@type nil|string[]
M._installable_parsers = nil

---@param dir string
local function source_dir(dir)
	pcall(vim.cmd.source, dir .. '/**/*.vim')
	pcall(vim.cmd.source, dir .. '/**/*.lua')
end

---@param installable string nix expression or |flake-output-attribute|, depending on `isExpr`
---@param isExpr boolean if true, treat `installable` as a nix expr, otherwise it is a |flake-output-attribute|
---@param succMsg string
---@param failMsg string
local function install_plugin(installable, isExpr, succMsg, failMsg)
	local cfg = require("nixrun").options
	local logs = {}

	local installable_args
	if isExpr then
		installable_args = { "--expr", installable }
	else
		installable_args = { installable }
	end

	vim.fn.jobstart(
		{ "nix", "build", "--print-out-paths", "--no-link", "--impure", "-I", string.format("nixpkgs=%s", cfg.nixpkgs),
			unpack(installable_args) },
		{
			on_exit = function(_, exitcode, _)
				if exitcode ~= 0 then
					vim.notify(failMsg .. "\n" .. table.concat(logs, "\n"), vim.log.levels.ERROR)
				end
			end,
			on_stdout = function(_, data, _)
				local pluginPath = data[1]
				if pluginPath == '' then
					vim.notify(failMsg .. "something went wrong", vim.log.levels.ERROR)
					return
				end
				if not vim.tbl_contains(vim.opt.runtimepath:get(), pluginPath) then
					vim.opt.runtimepath:prepend(pluginPath)
					-- mimics the behavior of :packadd
					source_dir(pluginPath .. '/plugin')
					-- XXX: I don't know if there's a better way to detect if ft detection is on
					if vim.fn.exists("#filetypedetect") == 1 then
						pcall(vim.cmd.source, pluginPath .. '/ftdetect/*.vim')
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
---@param name string A |flake-output-attribute| or grammar name, as listed in `nixpkgs#vimPlugins.nvim-treesitter.builtGrammars`
function M.includeGrammar(name)
	if name:match('#') then
		install_plugin(
			name,
			false,
			string.format('Added plugin "%s" to runtimepath', name),
			'nix building plugin "' .. name .. '": '
		)
	else
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

		install_plugin(
			expr,
			true,
			string.format('Added grammar "%s" to runtimepath', name),
			'nix building grammar "' .. name .. '": '
		)
	end
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
---@param name string A fully qualified flake output attribute (`nixpkgs#path.to.plugin`; `#` must be present) or plugin name, as listed in `nixpkgs#vimPlugins`
function M.includePlugin(name)
	if name:match('#') then
		install_plugin(
			name,
			false,
			string.format('Added plugin "%s" to runtimepath', name),
			'nix building plugin "' .. name .. '": '
		)
	else
		local expr = string.format(
			[[
		let
			pkgs = import <nixpkgs> {};
		in with pkgs;
			vimPlugins.%s
		]],
			name
		)

		install_plugin(
			expr,
			true,
			string.format('Added plugin "%s" to runtimepath', name),
			'nix building plugin "' .. name .. '": '
		)
	end
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
