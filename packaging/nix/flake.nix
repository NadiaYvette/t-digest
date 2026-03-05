{
  description = "Dunning t-digest implementations in 28 programming languages";

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
            # Systems languages
            gcc
            gnumake
            zig
            nim
            gnat

            # C++/D
            clang

            # Go
            go

            # Rust
            rustc
            cargo

            # JVM
            jdk
            kotlin

            # .NET
            dotnet-sdk

            # Functional
            ghc
            cabal-install
            mlton
            ocaml
            ocamlPackages.findlib
            erlang
            elixir

            # Logic
            swiProlog
            mercury

            # Scripting
            ruby
            python3
            perl
            lua

            # Scientific
            julia
            R

            # Lisp family
            sbcl
            chicken

            # Fortran
            gfortran

            # Swift
            swift
          ];

          shellHook = ''
            echo "t-digest development environment (28 languages)"
          '';
        };
      }
    );
}
