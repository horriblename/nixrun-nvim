`nix run` for your treesitter grammars (and possibly other plugins in the future)

Provides commands to easily install treesitter grammars _temporarily_. Think `:TSInstall` + `nix run`

# Setup

put this in your `init.lua`

```lua
require('nixrun').setup({})
```

# Usage

These commands are provided

```vim
NixRunTSGrammar # installs a treesitter parser for 
```
## Example

Say you're in a java file, even though you don't usually use java and probably won't ever touch one after this:

run

```vim
:NixRunTSGrammar java
```

Refresh your buffer (with `:edit`) after the install completes: you will get a notification when that happens.

# Note

1. You can install any grammar under `nixpkgs#vimPlugins.nvim-treesitter.builtGrammars`. Tab completion is available for `:NixRunTSGrammar`
2. I recommend you pin your nixpkgs registry by adding this to your NixOS/home-manager config:
   ```nix
   nix.registry.nixpkgs.flake = inputs.nixpkgs;
   ```
