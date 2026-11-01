if vim.g.nixrun_loaded then
	return
end

vim.g.nixrun_loaded = 1

local function log_error(msg)
	vim.notify(msg, vim.log.levels.ERROR, {})
end

vim.api.nvim_create_user_command(
	"NixRun",
	function(cmd_args)
		if cmd_args.fargs[1] == "lsp" then
			if cmd_args.fargs[2] == nil then
				log_error("Missing argument: lsp_name")
				return
			end

			require('nixrun.lazy').setupLsp(cmd_args.fargs[2])
		elseif cmd_args.fargs[1] == "plugin" then
			if cmd_args.fargs[2] == nil then
				log_error("Missing argument: plugin_installable")
				return
			end

			require('nixrun.lazy').includePlugin(cmd_args.fargs[2])
		elseif cmd_args.fargs[1] == "grammar" then
			if cmd_args.fargs[2] == nil then
				log_error("Missing argument: grammar_installable")
				return
			end

			require('nixrun.lazy').includeGrammar(cmd_args.fargs[2])
		elseif cmd_args.fargs[1] == "program" then
			if cmd_args.fargs[2] == nil then
				log_error("Missing argument: program")
				return
			end

			require('nixrun.lazy').includeProgram(cmd_args.fargs[2])
		elseif cmd_args.fargs[1] == "cancel" then
			local args = {}
			for i = 2, #cmd_args.fargs do
				args[#args + 1] = cmd_args.fargs[i]
			end

			local lazy = require('nixrun.lazy')
			local res
			if #args == 0 then
				res = lazy.cancel()
			elseif #args == 1 then
				res = lazy.cancel(args[1])
			else
				res = lazy.cancel(args[1], args[2])
			end

			vim.notify(string.format("[nixrun] cancelled %s job(s)", tostring(res)), vim.log.levels.INFO)
		elseif cmd_args.fargs[1] == "status" then
			print(require('nixrun.lazy').jobs_status())
		else
			log_error("Unknown subcommand " .. cmd_args.fargs[1])
		end
	end,
	{
		complete = 'custom,nixrun#cmd#cmdCompletion',
		nargs = '+',
	}
)

vim.api.nvim_create_user_command(
	"NixRunTSGrammar",
	function(cmd_args)
		vim.deprecate("NixRunTSGrammar", "NixRun grammar", "2.0")
		require("nixrun.lazy").includeGrammar(cmd_args.args)
	end,
	{
		complete = 'custom,nixrun#cmd#grammarCompletion',
		nargs = 1,
	}
)

vim.api.nvim_create_user_command(
	"NixRunPlugin",
	function(cmd_args)
		vim.deprecate("NixRunPlugin", "NixRun plugin", "2.0")
		require("nixrun.lazy").includePlugin(cmd_args.args)
	end,
	{
		complete = 'custom,nixrun#cmd#pluginCompletion',
		nargs = 1,
	}
)
