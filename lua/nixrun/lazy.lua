local M = {
	---@type table<NixRun.Category, table<string,vim.SystemObj>>
	_jobs = {
		plugins = {},
		programs = {},
		lsp = {},
		grammars = {},
	},
	_cancelled_jobs = setmetatable({}, { __mode = "k" }),
}

local async = require("nixrun.async")
local await = async.await
local pawait = async.pawait

---@alias NixRun.Category
--- | "plugins"
--- | "programs"
--- | "lsp"
--- | "grammars"

local cfg = require("nixrun.config")._config

local function truncate_line(lines, chars)
	chars = chars or 60
	local line = string.sub(lines, 1, chars)
	local short = string.match(line, "(.-)\n")
	if #short < #lines then
		return short .. "..."
	else
		return short
	end
end

-- normalize shorthand installable into a proper  flake output attribute
-- accepted by `nix build`
local function normalize_installable(installable, default_flakeref)
	if installable:find("#", 1, true)
		or installable:find(":", 1, true)
		or installable:find("/", 1, true)
	then
		-- already a proper output attribute flakeref#path
		-- or github:owner/repo or /path/to/repo
		return installable
	end

	return default_flakeref .. "#" .. installable
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

---@enum Environment
local Environment = {
	None = 0,
	PluginRtp = 1,
	Path = 2,
}

-- TODO: streamline error handling wtf is eventhis

---@param pluginPath string
---@return string? error
local function load_plugin_from_path(pluginPath)
	if vim.tbl_contains(vim.opt.runtimepath:get(), pluginPath) then
		return nil
	end
	vim.opt.runtimepath:prepend(pluginPath)
	-- mimics the behavior of :packadd
	source_dir(pluginPath .. '/plugin')
	if vim.fn.exists("#filetypedetect") == 1 then
		-- NOTE: vim.cmd.source throws an error if no files are found, which is not really a problem
		pcall(vim.cmd.source, pluginPath .. '/ftdetect/*.vim')
	end

	return nil
end

---@param path string
---@param env Environment
---@return string? error
local function add_path_to_evironment(path, env)
	if env == Environment.None then
		return nil
	elseif env == Environment.PluginRtp then
		return load_plugin_from_path(path)
	else
		path = vim.fs.joinpath(path, "bin")
		local PATH = os.getenv("PATH") or ""
		for p in vim.gsplit(PATH, ":", { plain = true }) do
			if p == path then
				return nil
			end
		end

		vim.fn.setenv("PATH", path .. ":" .. PATH)
	end
end

---@param paths string[]
---@param env Environment
---@param on_done fun(error: string?, plugin_paths: string[]?)
local function add_paths_to_environment(paths, env, on_done)
	local plugin_paths = vim.iter(paths):filter(function(line)
		return line ~= ""
	end)

	paths = plugin_paths:totable()

	local err = vim.iter(paths)
		:map(function(path)
			return add_path_to_evironment(path, env)
		end)
		:join('\n')

	if err ~= '' then
		on_done(err, paths)
		return
	end

	on_done(nil, paths)
end

---@param installable string the installable, see also `kind`
---@param kind InstallableType
---@param env Environment
---@param on_done fun(error: string?, paths: string[]?) The first entry in paths is the target plugin, rest are deps
---@param category NixRun.Category
---@return vim.SystemObj
local function add_to_environment(installable, kind, env, on_done, category)
	local nix_cmd
	---@type fun(paths: string[])
	local process_paths
	if kind == InstallableType.FlakeOutputAttribute then
		nix_cmd = { "nix", "build", "--print-out-paths", "--no-link", "--impure", "-I",
			string.format("nixpkgs=%s", cfg.nixpkgs) }
		vim.list_extend(nix_cmd, cfg.nix_build_flags or {})
		table.insert(nix_cmd, installable)

		process_paths = function(paths)
			add_paths_to_environment(paths, env, on_done)
		end
	elseif kind == InstallableType.FlakeRefUrl then
		nix_cmd = { "nix", "flake", "prefetch", "--json", installable }
		process_paths = function(paths)
			local fetch_result_json = paths[1]
			if fetch_result_json == '' then
				on_done("`nix flake prefetch` returned empty stdout")
				return
			end

			---@type string
			local plugin_path = vim.json.decode(fetch_result_json)['storePath']
			if plugin_path == nil then
				on_done("`nix flake prefetch` stdout does not contain JSON property 'storePath': " .. fetch_result_json)
				return
			end

			local err = load_plugin_from_path(plugin_path)
			if err ~= nil then
				on_done(err)
				return
			end

			on_done(nil, { plugin_path })
		end
	elseif kind == InstallableType.NixExpr then
		nix_cmd = { "nix", "build", "--print-out-paths", "--no-link", "--impure", "-I",
			string.format("nixpkgs=%s", cfg.nixpkgs) }
		vim.list_extend(nix_cmd, cfg.nix_build_flags or {})
		table.insert(nix_cmd, "--expr")
		table.insert(nix_cmd, installable)

		process_paths = function(lines)
			add_paths_to_environment(lines, env, on_done)
		end
	elseif kind == InstallableType.NixpkgsPlugin then
		local expr = string.format([[
			let
				pkgs = import <nixpkgs> {};
				target = pkgs.vimPlugins."%s";
			in
				[target] ++ (target.dependencies or [])
		]], vim.fn.escape(installable, '\\"$'))

		nix_cmd = { "nix", "build", "--print-out-paths", "--no-link", "--impure",
			"-I", string.format("nixpkgs=%s", cfg.nixpkgs),
		}
		vim.list_extend(nix_cmd, cfg.nix_build_flags or {})
		table.insert(nix_cmd, "--expr")
		table.insert(nix_cmd, expr)

		process_paths = function(lines)
			add_paths_to_environment(lines, env, on_done)
		end
	else
		error("install_plugin: unrecognized InstallableType " .. kind)
	end

	local job
	job = vim.system(
		nix_cmd,
		{ text = true, },
		vim.schedule_wrap(function(status)
			local cancelled = M._cancelled_jobs and M._cancelled_jobs[job]
			if M._cancelled_jobs then
				M._cancelled_jobs[job] = nil
			end
			if M._jobs[category] then
				M._jobs[category][installable] = nil
			end
			if cancelled then
				on_done("cancelled")
				return
			end
			if status.code ~= 0 then
				on_done("nix build failed, bad exit code: " .. status.code .. ", stderr:\n" .. status.stderr)
				return
			else
				process_paths(vim.split(status.stdout, "\n"))
			end
		end)
	)
	if M._jobs[category] then
		M._jobs[category][installable] = job
	end
	return job
end

---Installs the grammar asyncronously and add it to runtimepath upon completion
---@param name string A |flake-output-attribute| or grammar name, as listed in
---`nixpkgs#vimPlugins.nvim-treesitter.builtGrammars`
---@param on_done fun(err: string?, paths: string[]?)?
function M.includeGrammar(name, on_done)
	on_done = on_done or function(err)
		if err then
			vim.notify(string.format('nix building grammar "%s": %s', name, err), vim.log.levels.ERROR)
		else
			vim.notify(string.format('Added grammar "%s" to runtimepath', name), vim.log.levels.INFO)
		end
	end
	local done = function(err, p)
		if err == nil then
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_loaded(buf) and vim.treesitter.language.get_lang(vim.bo[buf].filetype) == name then
					vim.treesitter.start(buf)
				end
			end
		end
		if on_done then on_done(err, p) end
	end
	if name:match("#") then
		return add_to_environment(name, InstallableType.FlakeOutputAttribute, Environment.PluginRtp, function(err, p)
			if err then
				on_done(err)
				return
			end
			done(nil, p)
		end, "grammars")
	elseif name:match(":") or name:match("/") then
		done("Installing treesitter parsers with flakeref url style e.g. 'github:user/repo' is not supported yet.")
		return nil
	else
		-- TODO: avoid impure
		local expr = string.format(
			[[
		let
			pkgs = import <nixpkgs> {};
			grammar = pkgs.vimPlugins.nvim-treesitter.grammarPlugins.%s;
		in [
			grammar
			grammar.associatedQuery
		]
		]],
			name
		)

		return add_to_environment(
			expr,
			InstallableType.NixExpr,
			Environment.PluginRtp,
			done,
			"grammars"
		)
	end
end

---Installs the plugin asyncronously and add it to runtimepath upon completion
---@param name string A fully qualified flake output attribute (`nixpkgs#path.to.plugin`; `#` must be present) or plugin
---name, as listed in `nixpkgs#vimPlugins`
---@param on_done fun(err: string?, paths: string[]?)?
function M.includePlugin(name, on_done)
	on_done = on_done or function(err, paths)
		if err then
			vim.notify(string.format('nix building plugin "%s": %s', name, err), vim.log.levels.ERROR)
		else
			vim.notify(string.format('Added plugin "%s" and %d dependencies to runtimepath', name, #paths - 1))
		end
	end
	if name:match("#") then
		return add_to_environment(name, InstallableType.FlakeOutputAttribute, Environment.PluginRtp, on_done, "plugins")
	elseif name:match(":") then -- we don't accept /local/full/path here as you could just :set rtp^=/path
		return add_to_environment(name, InstallableType.FlakeRefUrl, Environment.PluginRtp, on_done, "plugins")
	else
		return add_to_environment(name, InstallableType.NixpkgsPlugin, Environment.PluginRtp, on_done, "plugins")
	end
end

---@type fun(program: string, on_done: fun(err: string?, package: string?))
local nix_locate_program = async.wrap(function(program, on_done)
	local cmd = {
		"nix-locate", "--minimal", "--no-group", "--type", "x", "--type", "s",
		"bin/" .. program,
	}
	---@type boolean, vim.SystemCompleted
	local ok, out = pawait(function(cb)
		vim.system(cmd, { text = true }, cb)
	end)

	if not ok then
		on_done("nix-locate: " .. out)
		return
	elseif out.code ~= 0 then
		on_done("nix-locate: failed, stderr: " .. truncate_line(out.stderr))
		return
	end

	local choices = {}
	for _, line in ipairs(vim.split(out.stdout, "\n")) do
		if line ~= "" then
			table.insert(choices, line)
		end
	end
	if #choices == 0 then
		on_done("nix-locate: no matches for /bin/" .. program)
		return
	elseif #choices == 1 then
		on_done(nil, choices[1])
		return
	else
		local prompt = "Which package to use as the provider of '" .. program .. "'?"
		---@type string?
		local chosen = await(function(cb)
			-- probably should wrap nix_locate_program instead
			vim.schedule_wrap(vim.ui.select)(choices, { prompt = prompt }, cb)
		end)

		if chosen == nil then
			on_done("user cancelled")
			return
		end
		on_done(nil, chosen)
		return
	end
end)

---@type fun(name: string, on_done: fun(err: string?)?)
M.setupLsp = async.wrap(function(name, on_done)
	on_done = on_done or function(err)
		if err then
			vim.notify(err, vim.log.levels.ERROR)
		else
			vim.notify(string.format("Done LSP setup: %s", name))
		end
	end

	local entry = vim.lsp.config[name]
	if entry == nil then
		local err = "no vim.lsp.config found for " .. name .. ", did you forget to install lspconfig?"
		on_done(err)
		return
	end
	local default_cmd = entry.cmd
	if default_cmd == nil then
		local err = "something went wrong: nil cmd in vim.lsp.config of " .. name .. ", please report this bug"
		on_done(err)
		return
	end

	local found, attr_path
	local tried_sources = {}

	-- configured overrides take precedence
	attr_path = cfg.lsp_overrides[name]
	found = attr_path ~= nil
	table.insert(tried_sources, "setup() lsp_overrides")

	if not found then
		local ok, v = pcall(require, "nixrun.overrides." .. name)
		if ok then
			vim.validate("nixrun.lsp." .. name .. ".package", v.package, "string")
			found, attr_path = true, v.package
		end
		table.insert(tried_sources, "builtin sources (overrides)")
	end

	if not found then
		local ok, v = pcall(require, "nixrun.lsp." .. name)
		if ok then
			vim.validate("nixrun.lsp." .. name .. ".package", v.package, "string")
			found, attr_path = true, v.package
		end
		table.insert(tried_sources, "builtin sources (script generated)")
	end

	if not found then
		local err
		err, attr_path = await(function(cb)
			nix_locate_program(default_cmd[1], cb)
		end)
		table.insert(tried_sources, "nix-locate")

		if err then
			err = err .. "\nTried sources:\n- " .. table.concat(tried_sources, "\n- ")
			on_done(err)
			return
		end
	end

	local pkg = normalize_installable(attr_path, "nixpkgs")

	local err, plugin_paths = await(function(cb)
		add_to_environment(pkg, InstallableType.FlakeOutputAttribute, Environment.None, cb, "lsp")
	end)

	if err then
		on_done(err)
		return
	end

	assert(#plugin_paths == 1)
	local pkg_path = plugin_paths[1]

	local cmd
	if type(default_cmd) == "table" then
		cmd = {
			vim.fs.joinpath(pkg_path, "bin", default_cmd[1]),
			unpack(default_cmd, 2),
		}
	else
		err = string.format("cmd of type %s not supported", type(default_cmd))
		on_done(err)
		return
	end
	vim.lsp.config(name, { cmd = cmd })
	vim.lsp.enable(name)

	on_done()
end)

---see |:NixRun program|
---@param name any
---@param on_done fun(err: string?)?
function M.includeProgram(name, on_done)
	on_done = on_done or function(err)
		if err then
			vim.notify(string.format("[nixrun] adding %s: %s", name, err), vim.log.levels.ERROR)
		else
			vim.notify(string.format("Done adding %s to $PATH", name))
		end
	end
	return add_to_environment(normalize_installable(name, "nixpkgs"), InstallableType.FlakeOutputAttribute,
		Environment.Path, on_done, "programs")
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

---@return table
function M.get_jobs()
	return M._jobs
end

function M.jobs_status()
	local lines = {}
	local function add_section(name, jobs)
		if not jobs or next(jobs) == nil then
			return
		end
		table.insert(lines, name .. ":")
		for key, job in pairs(jobs) do
			local status = "running"
			if type(job) == "table" and job.is_closing then
				local ok, r = pcall(function()
					return job:wait(0)
				end)
				if ok and r ~= nil then
					if r.signal and r.signal ~= 0 then
						status = "cancelled"
					elseif r.code == 0 then
						status = "done"
					else
						status = "failed"
					end
				elseif not ok then
					status = "unknown"
				end
			elseif type(job) == "number" then
				status = "unknown"
			end
			table.insert(lines, string.format("  %s: %s", key, status))
		end
		table.insert(lines, "")
	end

	add_section("plugins", M._jobs.plugins)
	add_section("grammars", M._jobs.grammars)
	add_section("lsp", M._jobs.lsp)
	add_section("programs", M._jobs.programs)

	if #lines == 0 then
		return "No jobs"
	end
	return table.concat(lines, "\n")
end

function M.print_jobs()
	print(M.jobs_status())
end

---Cancel a running job.
---
---Accepted forms:
---  M.cancel()                       cancel every running job
---  M.cancel(job)                    cancel a vim.SystemObj
---  M.cancel(name)                   cancel job(s) with this installable name
---  M.cancel(category)              cancel every job in a category
---  M.cancel(category, name)         cancel a specific job
---  M.cancel("all")                 cancel every running job
---@param ... any
---@return integer|boolean number of jobs cancelled, or success for single job
function M.cancel(...)
	local args = { ... }

	-- cancel everything
	if #args == 0 then
		local n = 0
		for category, jobs in pairs(M._jobs) do
			local names = {}
			for name, _ in pairs(jobs) do
				table.insert(names, name)
			end
			for _, name in ipairs(names) do
				if M.cancel_job(category, name) then
					n = n + 1
				end
			end
		end
		return n
	end

	if #args == 1 then
		local a = args[1]

		if type(a) == "table" and type(a.kill) == "function" then
			M._cancelled_jobs[a] = true
			for _, jobs in pairs(M._jobs) do
				for name, job in pairs(jobs) do
					if job == a then
						jobs[name] = nil
					end
				end
			end
			pcall(function()
				a:kill()
			end)
			return true
		end

		if type(a) == "string" then
			if a == "all" or a == "*" then
				return M.cancel()
			end

			-- category
			if M._jobs[a] ~= nil then
				local n = 0
				local names = {}
				for name, _ in pairs(M._jobs[a]) do
					table.insert(names, name)
				end
				for _, name in ipairs(names) do
					if M.cancel_job(a, name) then
						n = n + 1
					end
				end
				return n
			end

			-- name across categories
			local found = false
			for category, jobs in pairs(M._jobs) do
				if jobs[a] ~= nil then
					if M.cancel_job(category, a) then
						found = true
					end
				end
			end
			return found
		end

		return false
	end

	-- category, name
	local category = args[1]
	local name = args[2]
	if type(category) == "string" and type(name) == "string" then
		return M.cancel_job(category, name)
	end

	-- maybe name as second with job object first? handle job object
	if type(category) == "table" and type(category.kill) == "function" then
		return M.cancel(category)
	end

	return false
end

---Cancel a specific job by category and installable name.
---@param category string
---@param name string
---@return boolean
function M.cancel_job(category, name)
	if type(category) ~= "string" or type(name) ~= "string" then
		-- allow flexible usage
		return M.cancel(category, name) and true or false
	end
	local jobs = M._jobs[category]
	if not jobs then
		return false
	end
	local job = jobs[name]
	if not job then
		return false
	end
	M._cancelled_jobs[job] = true
	jobs[name] = nil
	pcall(function()
		job:kill('sigterm')
	end)
	return true
end

function M.cancel_all()
	return M.cancel()
end

function M.list_jobs()
	local out = {}
	for category, jobs in pairs(M._jobs) do
		for name, _ in pairs(jobs) do
			table.insert(out, name)
			table.insert(out, category .. " " .. name)
		end
	end
	return out
end

---Alias helpers for status viewing
function M.status()
	local s = M.jobs_status()
	print(s)
	return s
end

function M.job_status()
	return M.jobs_status()
end

function M.print_status()
	print(M.jobs_status())
end

return M
