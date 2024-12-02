local M = {}

if not _G.nixrun_config then
	_G.nixrun_config = {}
end

local cfg = _G.nixrun_config

local function default(val, def)
	if val ~= nil then
		return val
	end
	return def
end

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

	-- A nix expression
	-- TODO: currently only used by grammar installer, I should remove in
	-- favor of something more... limiting
	NixExpr = 3,

	-- e.g. multicursors-nvim
	-- (install_plugin resolves it to nixpkgs#vimPlugins.multicursors-nvim)
	NixpkgsPlugin = 4,
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

---@param paths string[]
---@param on_ok fun(plugin_paths: string[])
---@param on_fail fun(string)
local function load_plugin_paths(paths, on_ok, on_fail)
	local plugin_paths = vim.iter(paths)
		:filter(function(line) return line ~= "" end)

	paths = plugin_paths:totable()

	local err = vim.iter(paths)
		:map(load_plugin_from_path)
		:join('\n')

	if err ~= '' then
		on_fail(err)
		return
	end

	on_ok(paths)
end

---@param installable string nix expression or |flake-output-attribute|, depending on `isExpr`
---@param kind InstallableType if true, treat `installable` as a nix expr, otherwise it is a |flake-output-attribute|
---@param on_ok fun(paths: string[]) The first entry in paths is the target plugin, rest are dependencies
---@param on_fail fun(error: string)
local function install_plugin(installable, kind, on_ok, on_fail)
	local logs = {}

	local nix_cmd, on_stdout
	if kind == InstallableType.FlakeOutputAttribute then
		nix_cmd = { "nix", "build", "--print-out-paths", "--no-link", "--impure", "-I",
			string.format("nixpkgs=%s", default(cfg.nixpkgs, "nixpkgs")), installable }

		on_stdout = function(_, lines, _)
			load_plugin_paths(lines, on_ok, on_fail)
		end
	elseif kind == InstallableType.FlakeRefUrl then
		nix_cmd = { "nix", "flake", "prefetch", "--json", installable }
		on_stdout = function(_, data, _)
			local fetch_result_json = data[1]
			if fetch_result_json == '' then
				on_fail("`nix flake prefetch` returned empty stdout")
				return
			end

			---@type string
			local plugin_path = vim.json.decode(fetch_result_json)['storePath']
			if plugin_path == nil then
				on_fail("`nix flake prefetch` stdout does not contain JSON property 'storePath': " .. fetch_result_json)
				return
			end

			local err = load_plugin_from_path(plugin_path)
			if err ~= nil then
				on_fail(err)
				return
			end

			on_ok({ plugin_path })
		end
	elseif kind == InstallableType.NixExpr then
		nix_cmd = { "nix", "build", "--print-out-paths", "--no-link", "--impure", "-I",
			string.format("nixpkgs=%s", default(cfg.nixpkgs, "nixpkgs")), "--expr", installable }

		on_stdout = function(_, lines, _)
			load_plugin_paths(lines, on_ok, on_fail)
		end
	elseif kind == InstallableType.NixpkgsPlugin then
		local expr = string.format([[
			let
				pkgs = import <nixpkgs> {};
				target = pkgs.vimPlugins.%s;
			in
				[target] ++ (target.dependencies or [])
		]], vim.json.encode(installable)) -- not fool proof sanitization (${} not removed, but should be fine)

		nix_cmd = { "nix", "build", "--print-out-paths", "--no-link", "--impure",
			"-I", string.format("nixpkgs=%s", default(cfg.nixpkgs, "nixpkgs")),
			"--expr", expr,
		}

		on_stdout = function(_, lines, _)
			load_plugin_paths(lines, on_ok, on_fail)
		end
	else
		error("install_plugin: unrecognized InstallableType " .. kind)
	end

	vim.fn.jobstart(
		nix_cmd,
		{
			on_exit = function(_, exitcode, _)
				if exitcode ~= 0 then
					on_fail("bad exit code: " .. exitcode .. "\n\n" .. table.concat(logs, "\n"))
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
---@param on_done fun(paths: string[])?
function M.includeGrammar(name, on_done)
	if name:match('#') then
		install_plugin(
			name,
			InstallableType.FlakeOutputAttribute,
			function(p)
				if on_done then on_done(p) end
				vim.notify(
					string.format('Added grammar "%s" and %d dependencies to runtimepath', name),
					vim.log.levels.INFO
				)
			end,
			function(err)
				vim.notify(
					'nix building plugin "' .. name .. '": ' .. err,
					vim.log.levels.ERROR
				)
			end
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
			function(p)
				if on_done then on_done(p) end
				vim.notify(
					string.format('Added grammar "%s" to runtimepath', name),
					vim.log.levels.INFO
				)
			end,
			function(err)
				vim.notify(
					string.format('nix building grammar "%s": %s', name, err),
					vim.log.levels.ERROR
				)
			end
		)
	end
end

---Installs the plugin asyncronously and add it to runtimepath upon completion
---@param name string A fully qualified flake output attribute (`nixpkgs#path.to.plugin`; `#` must be present) or plugin name, as listed in `nixpkgs#vimPlugins`
---@param on_done fun(paths: string[])?
function M.includePlugin(name, on_done)
	if name:match('#') then
		install_plugin(
			name,
			InstallableType.FlakeOutputAttribute,
			function(p)
				if on_done then on_done(p) end
				vim.notify(
					string.format('Added plugin "%s" to runtimepath', name),
					vim.log.levels.INFO
				)
			end,
			function(err)
				vim.notify(
					string.format('nix building plugin "%s": %s', name, err),
					vim.log.levels.ERROR
				)
			end
		)
	elseif name:match(':') then
		install_plugin(
			name,
			InstallableType.FlakeRefUrl,
			function(p)
				if on_done then on_done(p) end
				vim.notify(string.format('Added plugin "%s" to runtimepath', name))
			end,
			function(err)
				vim.notify(string.format('nix fetching plugin "%s": %s', name, err), vim.log.levels.ERROR)
			end
		)
	else
		install_plugin(
			name,
			InstallableType.NixpkgsPlugin,
			function(plugin_paths)
				if on_done then on_done(plugin_paths) end
				vim.notify(string.format('Added plugin "%s" and %d dependencies to runtimepath', name, #plugin_paths - 1))
			end,
			function(err)
				vim.notify(string.format('nix building plugin "%s": %s', name, err), vim.log.levels.ERROR)
			end
		)
	end
end

---@param name string
---@param on_done fun()?
function M.setupLsp(name, on_done)
	local ok, value = pcall(require, 'nixrun.overrides.' .. name)
	if not ok then
		ok, value = pcall(require, 'nixrun.lsp.' .. name)
		if not ok then
			error("Config for LSP '" .. name .. "' not found. Please check if it's supported")
		end
	end

	local pkg = "nixpkgs#" .. value.package
	-- FIXME: don't add LSP to runtimepath
	install_plugin(pkg, InstallableType.FlakeOutputAttribute,
		function(plugin_paths)
			assert(#plugin_paths == 1)
			local pkg_path = plugin_paths[1]

			local default_cmd = require('lspconfig.server_configurations.' .. name).default_config.cmd
			local cmd = nil
			if type(default_cmd) == "table" then
				cmd = {
					vim.fs.joinpath(pkg_path, 'bin', default_cmd[1]),
					select(2, default_cmd)
				}
			else
				error(string.format('[nixrun] cmd of type %s not supported', type(default_cmd)))
			end
			require('lspconfig')[name].setup({
				cmd = cmd,
			})

			if on_done then on_done() end
			vim.notify(string.format('Done LSP setup: %s', name))
		end,
		function(err)
			vim.notify(string.format('[nixrun] setting up LSP %s: %s', name, err))
		end
	)
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
