# v2.0

Breaking:

- Deprecated `NixRunPlugin` and `NixRunTSGrammar`, use `NixRun plugin` or
  `NixRun grammar` instead.
- Callbacks now use a single `(err, ...)` style.
- Treesitter grammars are installed from `nvim-treesitter.grammarPlugins`.

Features:

- Added aggregate `:NixRun` command with `plugin`, `grammar`, `lsp`, and
  `program` subcommands.
- Added Lua API: `add_plugin()`, `add_grammar()`, `add_lsp()`, and
  `add_program()`.
- Added `:NixRun program` to add an installable to `$PATH`.
- Added LSP support via generated bindings and per-LSP overrides.
  - LSP packages are resolved with `nix-locate` when no override is available.
- Track running jobs with `jobs()`, `jobs_status()`, and `print_jobs()`.
- Added job control commands `:NixRun status` and `cancel`
