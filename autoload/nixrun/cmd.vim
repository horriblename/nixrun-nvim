" This file contains functions for commandline completion.
"
" Doing this in pure lua would mean only being able to use |:command-completion-customlist|,
" which would mean I need to implement my own caching solution and fuzzy match
" (this one is trivial via vim.fn.matchfuzzy)


fu! nixrun#cmd#grammarCompletion(_a, _b, _c)
	return join(v:lua.require'nixrun.lazy'.listAvailableGrammars(), "\n")
endfu

fu! nixrun#cmd#pluginCompletion(_a, _b, _c)
	return join(v:lua.require'nixrun.lazy'.listAvailablePlugins(), "\n")
endfu

fu! nixrun#cmd#lspCompletion(_a, _b, _c)
	let lsps = globpath(&rtp, 'lua/nixrun/lsp/*.lua', 0, 1)
	call map(lsps, "fnamemodify(v:val, ':t:r')")

	let overrides = globpath(&rtp, 'lua/nixrun/overrides/*.lua', 0, 1)
	call map(overrides, "fnamemodify(v:val, ':t:r')")

	return join(lsps + overrides, "\n")
endfu

fu! nixrun#cmd#cmdCompletion(argLead, cmdline, cursorPos)
	let argsBefore = split(a:cmdline[:a:cursorPos])
	if len(argsBefore) <= 1 || (len(argsBefore) == 2 && a:cmdline[a:cursorPos-1] !=# ' ')
		return "plugin\ngrammar\nlsp"
	endif

	if argsBefore[1] == 'plugin'
		return nixrun#cmd#pluginCompletion(a:argLead, a:cmdline, a:cursorPos)
	elseif argsBefore[1] == 'grammar'
		return nixrun#cmd#grammarCompletion(a:argLead, a:cmdline, a:cursorPos)
	elseif argsBefore[1] == 'lsp'
		return nixrun#cmd#lspCompletion(a:argLead, a:cmdline, a:cursorPos)
	endif
endfu
