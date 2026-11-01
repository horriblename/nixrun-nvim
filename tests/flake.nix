{
  description = "For testing use only";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };
  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;
    eachSystem = lib.genAttrs ["x86_64-linux"];
  in {
    packages = eachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      wait-5-min-and-fail = pkgs.callPackage ./wait-5-min-and-fail.nix {};
    });
  };
}
