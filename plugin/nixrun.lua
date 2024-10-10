---@param argLead string
---@return string[]
local function grammarCompletion(argLead, _, _)
	local grammars = require("nixrun.lazy").listAvailableGrammars()
	if argLead == '' then
		return grammars
	end
	return vim.fn.matchfuzzy(grammars, argLead)
end

---@param argLead string
---@return string[]
local function pluginCompletion(argLead, _, _)
	local grammars = require("nixrun.lazy").listAvailablePlugins()
	if argLead == '' then
		return grammars
	end
	return vim.fn.matchfuzzy(grammars, argLead)
end

local function cmdCompletion(argLead, cmdline, cursorPos)
	local argsBefore = vim.fn.split(string.sub(cmdline, 1, cursorPos), '', 1)
	if #argsBefore <= 2 then
		return vim.fn.matchfuzzy({ "plugin", "grammar", "lsp" }, argLead)
	end

	if argsBefore[2] == "plugin" then
		return pluginCompletion(argLead, cmdline, cursorPos)
	elseif argsBefore[2] == "grammar" then
		return grammarCompletion(argLead, cmdline, cursorPos)
	end
end

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
		complete = cmdCompletion,
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
		complete = grammarCompletion,
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
		complete = pluginCompletion,
		nargs = 1,
	}
)
