`nix run` for your treesitter grammars and arbitrary plugins

Provides commands to easily install treesitter grammars and plugins
_temporarily_.

# Setup

Install the plugin and use it directly. Configuration is optional:

```lua
require('nixrun').setup({
    nixpkgs = "nixpkgs",
    lsp_overrides = {
        lua_ls = "lua-language-server.out",
    },
})
```

See `doc/nixrun.txt` for details.

# Usage

These commands are provided

```vim
NixRun grammar <lang>   " installs a treesitter parser
NixRun plugin  <plugin> " installs a vim plugin
NixRun lsp     <lspconfig_name> " install and sets up an lsp via lspconfig
NixRun program <program> " adds an installable to $PATH
```

- Treesitter parsers are taken from
  `nixpkgs#vimPlugins.nvim-treesitter.builtGrammars`
- Plugins are taken from `nixpkgs#vimPlugins`, or a custom flake:
  `yourFlake#some-plugin`, or a flakeref URL: `github:t-troebst/perfanno.nvim`
- LSPs support is very experimental, and are configured via lspconfig.
  - LSP packages are mostly generated from a script so your mileage may vary.

- Tab completion is available for the simple nixpkgs parsers/plugins

## Example

```vim
" Installing treesitter grammars:
NixRun grammar java    " please reload your buffer after install to use the treesitter grammar

" Installing a plugin
NixRun plugin oil-nvim   " installs nixpkgs#vimPlugins.oil-nvim + dependencies
NixRun plugin custom-flake#custom-plugin       " installs a custom packaged plugin
NixRun plugin github:t-troebst/perfanno.nvim   " pull the plugin source from github (not a nix package)

" Installing an LSP
NixRun lsp vala_ls " This is the name listed by lspconfig

" Adding a program to $PATH
NixRun program nixpkgs#python3
```

# Note

- I recommend you pin your nixpkgs registry by adding this to your
  NixOS/home-manager config (mismatched neovim and grammar versions might cause
  unexpected errors):
  ```nix
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  ```
