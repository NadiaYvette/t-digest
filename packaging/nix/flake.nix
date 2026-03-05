{
  description = "Dunning t-digest implementations in multiple languages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        t-digest = pkgs.callPackage ./default.nix { };

      in
      {
        packages.default = t-digest;
        packages.t-digest = t-digest;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Ruby
            ruby

            # Haskell
            ghc
            cabal-install

            # Common Lisp
            sbcl

            # Scheme
            guile

            # SML
            mlton

            # Ada
            gnat

            # Prolog
            swiProlog

            # Mercury
            mercury
          ];

          shellHook = ''
            echo "t-digest multi-language development environment"
            echo "Available languages: Ruby, Haskell, Common Lisp, Scheme, SML, Ada, Prolog, Mercury"
          '';
        };
      }
    );
}
