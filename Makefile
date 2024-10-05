.PHONY: run

run:
	nvim --cmd 'lua (function() vim.opt.runtimepath:prepend("."); require"nixrun".setup() end)()'

gen-lsp-config:
	nvim +'luafile ./scripts/lspconfig-finder.lua' +q --headless
	go run ./scripts/parser.go
