.PHONY: run

run:
	nvim -u NORC --cmd 'lua vim.opt.runtimepath:prepend(vim.fn.expand(".")); require"nixrun".setup()'

test-e2e:
	nvim -u NORC --headless --cmd 'lua vim.opt.runtimepath:prepend(vim.fn.expand("."))' +'luafile tests/e2e.lua'

gen-lsp-config:
	nvim -u NONE --headless +q \
		--cmd 'lua vim.opt.runtimepath:prepend(vim.fn.expand("."))' \
		--cmd 'luafile ./scripts/lspconfig-finder.lua'
