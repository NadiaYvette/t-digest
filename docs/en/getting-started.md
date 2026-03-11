# Getting Started

Each language implementation is self-contained in its own directory.
There are no cross-language dependencies.

---

## Haskell

**Prerequisites:** GHC, `fingertree` and `vector` packages

**Standalone (no build tool):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**As a Cabal package (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

The Cabal package exposes two library modules:
`Data.Sketch.TDigest` (pure, finger-tree-backed) and
`Data.Sketch.TDigest.Mutable` (mutable, ST monad with vectors).

**Using in your own code:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**Prerequisites:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

The file `tdigest.rb` contains both the library and a demo in the
`if __FILE__ == $PROGRAM_NAME` block. To use it as a library:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**Prerequisites:** GNAT (GCC Ada compiler)

```bash
cd ada/
gnatmake demo.adb
./demo
```

The package is split into `tdigest.ads` (spec), `tdigest.adb` (body),
and the generic `tree234.ads`/`tree234.adb` 2-3-4 tree package.
To use in your own project, `with TDigest;` in your source and compile
all files together.

---

## Common Lisp

**Prerequisites:** SBCL, or any ANSI Common Lisp implementation

```bash
cd common-lisp/
sbcl --script demo.lisp
```

To use interactively:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**Prerequisites:** CHICKEN Scheme (`csi`), or any R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Or with Guile:

```bash
guile demo.scm
```

Note: The `+inf.0` and `-inf.0` literals are used for infinity. If your
Scheme implementation uses different constants, you may need to adjust
the definitions of `+inf` and `-inf` at the top of `tdigest.scm`.

---

## Standard ML

**Prerequisites:** MLton (for compilation) or SML/NJ (for interactive use)

**With MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**With SML/NJ:**

```bash
cd sml/
sml demo.sml
```

The MLB file (`demo.mlb`) lists the basis library and source files for
MLton's build system.

---

## Prolog

**Prerequisites:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

The demo loads the `tdigest` module and runs automatically via the
`:- initialization(main, main).` directive.

To use interactively:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**Prerequisites:** Mercury compiler (`mmc`)

**Pure functional version** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Mutable version** (2-3-4 tree with uniqueness types):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

The Mercury build system will automatically compile dependencies
(`tdigest.m`, `fingertree.m`, `measured_tree234.m`, etc.).

---

## C

**Prerequisites:** GCC or Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**Prerequisites:** G++ or Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**Prerequisites:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**Prerequisites:** Cargo and Rust toolchain

```bash
cd rust/
cargo run --release
```

---

## Java

**Prerequisites:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**Prerequisites:** Kotlin compiler

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**Prerequisites:** Python 3 (no external dependencies)

```bash
cd python/
python3 demo.py
```

---

## Julia

**Prerequisites:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**Prerequisites:** OCaml compiler with ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**Prerequisites:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**Prerequisites:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**Prerequisites:** GFortran or other Fortran 2003+ compiler

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**Prerequisites:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**Prerequisites:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**Prerequisites:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**Prerequisites:** Zig compiler

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**Prerequisites:** Nim compiler

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**Prerequisites:** DMD or LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**Prerequisites:** .NET SDK or Mono

**With .NET SDK:**

```bash
cd csharp/
dotnet run
```

**With Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**Prerequisites:** Swift compiler

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
