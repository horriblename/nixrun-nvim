.PHONY: run

run:
	nvim -u NORC --cmd 'lua vim.opt.runtimepath:prepend(vim.fn.expand(".")); require"nixrun".setup()'

gen-lsp-config:
	nvim +'luafile ./scripts/lspconfig-finder.lua' +q --headless
	go run ./scripts/parser.go
