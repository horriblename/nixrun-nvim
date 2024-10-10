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

vim.api.nvim_create_user_command(
	"NixRunPlugin",
	function(cmd_args)
		require("nixrun.lazy").includePlugin(cmd_args.args)
	end,
	{
		complete = pluginCompletion,
		nargs = 1,
	}
)

vim.api.nvim_create_user_command(
	"NixRunLsp",
	function(cmd_args)
		require("nixrun.lazy").setupLsp(cmd_args.args)
	end,
	{
		complete = pluginCompletion,
		nargs = 1,
	}
)
