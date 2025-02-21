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
		vim.deprecate("NixRunTSGrammar", "NixRun grammar")
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
		vim.deprecate("NixRunPlugin", "NixRun plugin")
		require("nixrun.lazy").includePlugin(cmd_args.args)
	end,
	{
		complete = 'custom,nixrun#cmd#pluginCompletion',
		nargs = 1,
	}
)
