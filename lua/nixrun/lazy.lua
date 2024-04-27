local M = {}

---@type nil|string[]
M._installable_parsers = nil

---@param dir string
local function source_dir(dir)
	pcall(vim.cmd.source, dir .. '/**/*.vim')
	pcall(vim.cmd.source, dir .. '/**/*.lua')
end

---@enum InstallableType
local InstallableType = {
	-- e.g. 'flakeref#package', see |flake-output-attribute|.
	FlakeOutputAttribute = 1,
	-- A flakeref url, e.g. github:user/repo
	FlakeRefUrl = 2,
	NixExpr = 3,
}

local errPluginAlreadyLoaded = "plugin already loaded"

---@param pluginPath string
---@return string? error
local function load_plugin_from_path(pluginPath)
	if vim.tbl_contains(vim.opt.runtimepath:get(), pluginPath) then
		return errPluginAlreadyLoaded
	end
	vim.opt.runtimepath:prepend(pluginPath)
	-- mimics the behavior of :packadd
	source_dir(pluginPath .. '/plugin')
	-- XXX: I don't know if there's a better way to detect if ft detection is on
	if vim.fn.exists("#filetypedetect") == 1 then
		-- NOTE: vim.cmd.source throws an error if no files are found, which is not really a problem
		pcall(vim.cmd.source, pluginPath .. '/ftdetect/*.vim')
	end

	return nil
end

local function on_nix_build_stdout(succMsg, failMsg)
	return function(_, data, _)
		local pluginPath = data[1]
		if pluginPath == '' then
			vim.notify(failMsg .. "something went wrong", vim.log.levels.ERROR)
			return
		end

		local err = load_plugin_from_path(pluginPath)
		if err ~= nil then
			vim.notify(failMsg .. err, vim.log.levels.ERROR)
			return
		end

		vim.notify(succMsg)
	end
end

---@param installable string nix expression or |flake-output-attribute|, depending on `isExpr`
---@param kind InstallableType if true, treat `installable` as a nix expr, otherwise it is a |flake-output-attribute|
---@param succMsg string
---@param failMsg string
local function install_plugin(installable, kind, succMsg, failMsg)
	local cfg = require("nixrun").options
	local logs = {}

	local nix_cmd, on_stdout
	if kind == InstallableType.FlakeOutputAttribute then
		nix_cmd = { "nix", "build", "--print-out-paths", "--no-link", "--impure", "-I",
			string.format("nixpkgs=%s", cfg.nixpkgs), installable }
		on_stdout = on_nix_build_stdout(succMsg, failMsg)
	elseif kind == InstallableType.FlakeRefUrl then
		nix_cmd = { "nix", "flake", "prefetch", "--json", installable }
		on_stdout = function(_, data, _)
			local fetch_result_json = data[1]
			if fetch_result_json == '' then
				vim.notify(failMsg .. "something went wrong", vim.log.levels.ERROR)
				return
			end

			---@type string
			local plugin_path = vim.json.decode(fetch_result_json)['storePath']
			if plugin_path == nil then
				vim.notify(
					failMsg .. "`nix flake prefetch` stdout does not contain JSON property 'storePath': " .. fetch_result_json,
					vim.log.levels.ERROR)
				return
			end

			local err = load_plugin_from_path(plugin_path)
			if err ~= nil then
				vim.notify(failMsg .. err, vim.log.levels.ERROR)
				return
			end

			vim.notify(succMsg)
		end
	else
		nix_cmd = { "nix", "build", "--print-out-paths", "--no-link", "--impure", "-I",
			string.format("nixpkgs=%s", cfg.nixpkgs), "--expr", installable }
		on_stdout = on_nix_build_stdout(succMsg, failMsg)
	end

	vim.fn.jobstart(
		nix_cmd,
		{
			on_exit = function(_, exitcode, _)
				if exitcode ~= 0 then
					vim.notify(failMsg .. "\n" .. table.concat(logs, "\n"), vim.log.levels.ERROR)
				end
			end,
			on_stdout = on_stdout,
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
			InstallableType.FlakeOutputAttribute,
			string.format('Added plugin "%s" to runtimepath', name),
			'nix building plugin "' .. name .. '": '
		)
	elseif name:match(':') then
		vim.notify("Installing treesitter parsers with flakeref url style e.g. 'github:user/repo' is not supported yet.",
			vim.log.levels.ERROR)
		-- install_plugin(
		-- 	name,
		-- 	InstallableType.FlakeRefUrl,
		-- 	string.format('Added plugin "%s" to runtimepath', name),
		-- 	'nix building plugin "' .. name .. '": '
		-- )
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
			InstallableType.NixExpr,
			string.format('Added grammar "%s" to runtimepath', name),
			'nix building grammar "' .. name .. '": '
		)
	end
end

---Installs the plugin asyncronously and add it to runtimepath upon completion
---@param name string A fully qualified flake output attribute (`nixpkgs#path.to.plugin`; `#` must be present) or plugin name, as listed in `nixpkgs#vimPlugins`
function M.includePlugin(name)
	if name:match('#') then
		install_plugin(
			name,
			InstallableType.FlakeOutputAttribute,
			string.format('Added plugin "%s" to runtimepath', name),
			'nix building plugin "' .. name .. '": '
		)
	elseif name:match(':') then
		install_plugin(
			name,
			InstallableType.FlakeRefUrl,
			string.format('Added plugin "%s" to runtimepath', name),
			string.format('nix fetching plugin "%s"', name)
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
			InstallableType.NixExpr,
			string.format('Added plugin "%s" to runtimepath', name),
			'nix building plugin "' .. name .. '": '
		)
	end
end

---@return string[]
function M.listAvailableGrammars()
	if M._installable_parsers then
		return M._installable_parsers
	end

	local stdout, stderr
	local cmd = { "nix", "eval", "--json", "nixpkgs#vimPlugins.nvim-treesitter.builtGrammars", "--apply",
		"builtins.attrNames" }

	local job_id = vim.fn.jobstart(
		cmd,
		{
			on_exit = function(_, exitcode, _)
				if exitcode ~= 0 then
					vim.notify(table.concat(stderr, "\n"), vim.log.levels.ERROR)
				end
			end,
			on_stdout = function(_, data, _) stdout = data end,
			on_stderr = function(_, data, _) stderr = data end,
			stdout_buffered = true,
			stderr_buffered = true,
		}
	)

	-- TODO: handle jobwait errors
	vim.fn.jobwait({ job_id })
	M._installable_parsers = vim.fn.json_decode(stdout)
	return M._installable_parsers
end

---@return string[]
function M.listAvailablePlugins()
	if M._installable_plugins then
		return M._installable_plugins
	end

	local stderr, stdout

	local cmd = { "nix", "eval", "--json", "nixpkgs#vimPlugins", "--apply", "builtins.attrNames" }
	local job_id = vim.fn.jobstart(
		cmd,
		{
			on_exit = function(_, exitcode, _)
				if exitcode ~= 0 then
					vim.notify(table.concat(stderr, "\n"), vim.log.levels.ERROR)
				end
			end,
			on_stdout = function(_, data, _) stdout = data end,
			on_stderr = function(_, data, _) stderr = data end,
			stdout_buffered = true,
			stderr_buffered = true,
		}
	)

	-- TODO: handle jobwait errors
	vim.fn.jobwait({ job_id })
	M._installable_plugins = vim.fn.json_decode(stdout)
	return M._installable_plugins
end

return M
