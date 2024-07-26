{
  description = "A basic flake";
  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;
    # should probably get systems from nixpkgs or something
    eachSystem = lib.genAttrs ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
    pkgsFor = eachSystem (
      system:
        import nixpkgs {
          localSystem = system;
          overlays = [self.overlays.default];
        }
    );
  in {
    lib = {
      # note: needs to pass {pkgs} to this function
      lspconfig = import ./nix/lspconfig.nix;
    };

    # devShells = eachSystem (system: let
    #   pkgs = pkgsFor.${system};
    # in {
    #   default = pkgs.mkShell {
    #     nativeBuildInputs = with pkgs; [];
    #   };
    # });
  };
}
