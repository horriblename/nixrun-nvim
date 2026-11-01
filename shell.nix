{pkgs ? import <nixpkgs> {}}: let
  inherit (builtins) concatStringsSep;

  neovimPkg = {
    symlinkJoin,
    neovim-unwrapped,
    makeWrapper,
    plugins,
  }: let
    pluginPaths = concatStringsSep "," plugins;
  in
    symlinkJoin {
      name = "neovim-custom";
      paths = [neovim-unwrapped];
      nativeBuildInputs = [makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/nvim \
          --add-flags '-u' \
          --add-flags 'NONE' \
          --add-flags '--cmd' \
          --add-flags '"set rtp^=${pluginPaths}"'
      '';
    };

  neovim = pkgs.callPackage neovimPkg {
    plugins = [pkgs.vimPlugins.nvim-lspconfig];
  };
in
  pkgs.mkShellNoCC {
    packages = [neovim];
  }
