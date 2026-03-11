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
| Ada           | `ada/`         | `tdigest.ads/adb`, `tree234.ads/adb` | Generic 2-3-4 tree  |
| C             | `c/`           | `tdigest.h`, `tdigest.c`            | Embedded 2-3-4 tree |
| C++           | `cpp/`         | `tdigest.hpp/cpp`, `tree234.hpp`     | Template 2-3-4 tree |
| C#            | `csharp/`      | `TDigest.cs`, `Tree234.cs`           | Generic 2-3-4 tree  |
| Common Lisp   | `common-lisp/` | `tdigest.lisp`, `tree234.lisp`       | Defstruct 2-3-4 tree|
| D             | `d/`           | `tdigest.d`, `tree234.d`             | Template 2-3-4 tree |
| Elixir        | `elixir/`      | `tdigest.ex`                         | Functional/struct   |
| Erlang        | `erlang/`      | `tdigest.erl`                        | Functional/records  |
| Fortran       | `fortran/`     | `tdigest.f90`                        | Embedded 2-3-4 tree |
| Go            | `go/`          | `tdigest.go`, `tree234.go`           | Generic 2-3-4 tree  |
| Haskell       | `haskell/`     | `TDigest.hs`, `TDigestM.hs` (`dunning-t-digest` on Hackage) | Finger tree + mutable ST vectors |
| Java          | `java/`        | `TDigest.java`, `Tree234.java`       | Generic 2-3-4 tree  |
| Julia         | `julia/`       | `TDigest.jl`, `Tree234.jl`           | Parametric 2-3-4 tree|
| Kotlin        | `kotlin/`      | `TDigest.kt`, `Tree234.kt`           | Generic 2-3-4 tree  |
| Lua           | `lua/`         | `tdigest.lua`, `tree234.lua`         | Callback 2-3-4 tree |
| Mercury       | `mercury/`     | `tdigest.m`, `fingertree.m`, `tdigest_mut.m`, `measured_tree234.m` | Finger tree + typeclass 2-3-4 tree |
| Nim           | `nim/`         | `tdigest.nim`, `tree234.nim`         | Generic 2-3-4 tree  |
| OCaml         | `ocaml/`       | `tdigest.ml`                         | Embedded 2-3-4 tree |
| Perl          | `perl/`        | `TDigest.pm`, `Tree234.pm`           | Coderef 2-3-4 tree  |
| Prolog        | `prolog/`      | `tdigest.pl`                         | Logic/relational    |
| Python        | `python/`      | `tdigest.py`, `tree234.py`           | Callback 2-3-4 tree |
| R             | `r/`           | `tdigest.R`, `tree234.R`             | Environment 2-3-4 tree|
| Ruby          | `ruby/`        | `tdigest.rb`, `tree234.rb`           | Lambda 2-3-4 tree   |
| Rust          | `rust/`        | `src/lib.rs`, `src/tree234.rs`       | Trait 2-3-4 tree    |
| Scheme        | `scheme/`      | `tdigest.scm`                        | Functional/mutable  |
| Standard ML   | `sml/`         | `tdigest.sml`                        | Augmented BST       |
| Swift         | `swift/`       | `tdigest.swift`, `tree234.swift`     | Protocol 2-3-4 tree |
| Zig           | `zig/`         | `tdigest.zig`, `tree234.zig`         | Comptime 2-3-4 tree |

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
cd java/ && javac Tree234.java TDigest.java Demo.java && java Demo

# Python
cd python/ && python3 demo.py

# Ruby
cd ruby/ && ruby tdigest.rb

# Haskell (standalone)
cd haskell/ && ghc -O2 -o demo Main.hs && ./demo
# Haskell (cabal)
cd haskell/ && cabal run dunning-t-digest-demo

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
cd d/ && dmd -O -of=demo demo.d tdigest.d tree234.d && ./demo

# Kotlin
cd kotlin/ && kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar && java -jar demo.jar

# C#
cd csharp/ && dotnet run

# Swift
cd swift/ && swiftc -O -o demo tree234.swift tdigest.swift demo.swift && ./demo
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

The t-digest maintains a sorted collection of weighted centroids that
approximate the empirical CDF. A scale function (K1 / arcsine) ensures
that centroids near the tails (q near 0 or 1) are kept small for high
accuracy, while centroids near the median can grow large to save space.

Internally, most implementations store centroids in an array-backed
**2-3-4 tree** with four-component monoidal measures (weight, count,
maxMean, meanWeightSum), giving O(log n) insertion and search. The
purely functional implementations (Haskell, Mercury, SML) use finger
trees or augmented BSTs with the same monoidal annotation scheme.

Key properties:

- **O(1) amortized add** (buffer-based) or **O(log n) add** (tree-based)
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
