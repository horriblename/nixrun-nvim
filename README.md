`nix run` for your treesitter grammars and arbitrary plugins

Provides commands to easily install treesitter grammars and plugins _temporarily_.

# Setup

put this in your `init.lua`

```lua
require('nixrun').setup({})
```

# Usage

These commands are provided

```vim
NixRunTSGrammar # installs a treesitter parser
NixRunPlugin    # installs a vim plugin
```

- Treesitter parsers are taken from `nixpkgs#vimPlugins.nvim-treesitter.builtGrammars`
- Plugins are taken from `nixpkgs#vimPlugins`,
  or a custom flake: `yourFlake#some-plugin`,
  or a flakeref URL: `github:t-troebst/perfanno.nvim`

- Tab completion is available for the simple nixpkgs parsers/plugins

## Example

```vim
" Installing treesitter grammars:
NixRunTSGrammar java    " please reload your buffer after install to use the treesitter grammar

" Installing a plugin
NixRunPlugin oil-nvim   " installs nixpkgs#vimPlugins.oil-nvim + dependencies
NixRunPlugin custom-flake#custom-plugin       " installs a custom packaged plugin
NixRunPlugin github:t-troebst/perfanno.nvim   " pull the plugin source from github (not a nix package)
```

# Note

- I recommend you pin your nixpkgs registry by adding this to your NixOS/home-manager config
  (mismatched neovim and grammar versions might cause unexpected errors):
  ```nix
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  ```
