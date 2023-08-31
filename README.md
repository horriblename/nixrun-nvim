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

- Treesitter parsers are taken from `nixpkgs#vimPlugins.nvim-treesitter.builtGrammars`.
- Plugins are taken from `nixpkgs#vimPlugins`
- Tab completion is available

## Example

Installing treesitter grammars:

```vim
:NixRunTSGrammar java
```

Refresh your buffer (with `:edit`) after the install completes: you will get a notification when that happens.

# Note

- I recommend you pin your nixpkgs registry by adding this to your NixOS/home-manager config:
  ```nix
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  ```
