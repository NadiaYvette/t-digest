# t-digest

Online quantile estimation with the Dunning t-digest algorithm.

<!-- badges -->
![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

## Overview

This repository contains implementations of the **merging t-digest** data
structure in 28 programming languages. The t-digest provides fast,
memory-bounded, mergeable approximation of quantiles (percentiles) from
streaming data, with especially high accuracy in the tails (p99, p99.9,
etc.).

All implementations use the **K1 (arcsine) scale function** as described
in Dunning & Ertl (2019).

## Implementations

| Language      | Directory      | Files                              | Style              |
|---------------|----------------|------------------------------------|---------------------|
| Ada           | `ada/`         | `tdigest.ads`, `tdigest.adb`      | Imperative/record   |
| C             | `c/`           | `tdigest.h`, `tdigest.c`          | Procedural          |
| C++           | `cpp/`         | `tdigest.hpp`, `tdigest.cpp`      | Object-oriented     |
| C#            | `csharp/`      | `TDigest.cs`                      | Object-oriented     |
| Common Lisp   | `common-lisp/` | `tdigest.lisp`                    | Struct-based        |
| D             | `d/`           | `tdigest.d`                       | Struct-based        |
| Elixir        | `elixir/`      | `tdigest.ex`                      | Functional/struct   |
| Erlang        | `erlang/`      | `tdigest.erl`                     | Functional/records  |
| Fortran       | `fortran/`     | `tdigest.f90`                     | Module/derived type |
| Go            | `go/`          | `tdigest.go`                      | Struct/methods      |
| Haskell       | `haskell/`     | `TDigest.hs`                      | Pure functional     |
| Java          | `java/`        | `TDigest.java`                    | Object-oriented     |
| Julia         | `julia/`       | `TDigest.jl`                      | Multiple dispatch   |
| Kotlin        | `kotlin/`      | `TDigest.kt`                      | Object-oriented     |
| Lua           | `lua/`         | `tdigest.lua`                     | Table-based OOP     |
| Mercury       | `mercury/`     | `tdigest.m`                       | Pure functional     |
| Nim           | `nim/`         | `tdigest.nim`                     | Object/proc-based   |
| OCaml         | `ocaml/`       | `tdigest.ml`                      | Functional/record   |
| Perl          | `perl/`        | `TDigest.pm`                      | OOP (bless-based)   |
| Prolog        | `prolog/`      | `tdigest.pl`                      | Logic/relational    |
| Python        | `python/`      | `tdigest.py`                      | Class-based         |
| R             | `r/`           | `tdigest.R`                       | Environment-based   |
| Ruby          | `ruby/`        | `tdigest.rb`                      | Object-oriented     |
| Rust          | `rust/`        | `src/lib.rs`                      | Struct/impl         |
| Scheme        | `scheme/`      | `tdigest.scm`                     | Functional/mutable  |
| Standard ML   | `sml/`         | `tdigest.sml`                     | Pure functional     |
| Swift         | `swift/`       | `tdigest.swift`                   | Struct/mutating     |
| Zig           | `zig/`         | `tdigest.zig`                     | Procedural/struct   |

## Quick Start

Each language directory contains a library file and a `demo` program.

```bash
# C
cd c/ && gcc -O2 -lm -o demo demo.c tdigest.c && ./demo

# C++
cd cpp/ && g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp && ./demo

# Go
cd go/demo && go run .

# Rust
cd rust/ && cargo run --release

# Java
cd java/ && javac TDigest.java Demo.java && java Demo

# Python
cd python/ && python3 demo.py

# Ruby
cd ruby/ && ruby tdigest.rb

# Haskell
cd haskell/ && ghc -O2 -o demo Main.hs && ./demo

# Ada
cd ada/ && gnatmake -O2 demo.adb -o demo && ./demo

# Common Lisp
cd common-lisp/ && sbcl --script demo.lisp

# Scheme
cd scheme/ && csi -R r5rs -script demo.scm

# Standard ML
cd sml/ && mlton demo.mlb && ./demo

# Prolog
cd prolog/ && swipl demo.pl

# Mercury
cd mercury/ && mmc --make demo && ./demo

# OCaml
cd ocaml/ && ocamlfind ocamlopt tdigest.ml demo.ml -o demo && ./demo

# Julia
cd julia/ && julia demo.jl

# Erlang
cd erlang/ && erlc tdigest.erl demo.erl && erl -noshell -s demo main -s init stop

# Elixir
cd elixir/ && elixir demo.exs

# Fortran
cd fortran/ && gfortran -O2 -o demo tdigest.f90 demo.f90 && ./demo

# Perl
cd perl/ && perl -I. demo.pl

# Lua
cd lua/ && lua demo.lua

# R
cd r/ && Rscript demo.R

# Zig
cd zig/ && zig build-exe demo.zig -O ReleaseFast && ./demo

# Nim
cd nim/ && nim c -d:release -o:demo demo.nim && ./demo

# D
cd d/ && dmd -O -of=demo demo.d tdigest.d && ./demo

# Kotlin
cd kotlin/ && kotlinc TDigest.kt Demo.kt -include-runtime -d demo.jar && java -jar demo.jar

# C#
cd csharp/ && dotnet run

# Swift
cd swift/ && swiftc -O -o demo tdigest.swift demo.swift && ./demo
```

## Documentation

Full documentation is available in the `docs/` directory and can be
built with [mdBook](https://rust-lang.github.io/mdBook/):

```bash
cd docs/
mdbook build
```

The documentation includes:

- **Introduction** -- What is a t-digest and why use it
- **Building Intuition** -- A gentle, diagram-heavy walkthrough of the
  core ideas
- **Algorithm Details** -- Formal pseudocode, scale function variants,
  accuracy analysis, and comparison with other quantile sketches
- **API Reference** -- Function signatures and usage for all
  language implementations
- **Getting Started** -- Build and run instructions for every language
- **References** -- Academic papers and related work

Documentation is available in 36 languages including English, Hindi,
Bengali, Tamil, Japanese, Korean, Chinese, Arabic, Lojban, Toki Pona,
and more.

## Algorithm Summary

The t-digest maintains a sorted list of weighted centroids that
approximate the empirical CDF. A scale function (K1 / arcsine) ensures
that centroids near the tails (q near 0 or 1) are kept small for high
accuracy, while centroids near the median can grow large to save space.

Key properties:

- **O(1) amortized add** (for fixed compression parameter delta)
- **O(delta) space** -- typically a few hundred centroids
- **Mergeable** -- combine digests from distributed workers in
  O(delta log delta) time
- **High tail accuracy** -- error shrinks as you approach q=0 or q=1

## License

MIT License

Copyright (c) 2025 Nadia Yvette Chambers

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Citation

If you use this software in academic work, please cite:

```bibtex
@article{dunning2019computing,
  title={Computing Extremely Accurate Quantiles Using t-Digests},
  author={Dunning, Ted and Ertl, Otmar},
  journal={arXiv preprint arXiv:1902.04023},
  year={2019}
}
```
