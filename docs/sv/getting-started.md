# Kom igång

Varje språkimplementation är fristående i sin egen katalog.
Det finns inga beroenden mellan språken.

---

## Haskell

**Förutsättningar:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

Modulen `TDigest` använder bara `base`-bibliotek (inget Cabal- eller Stack-projekt krävs).

**Användning i egen kod:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**Förutsättningar:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

Filen `tdigest.rb` innehåller både biblioteket och en demo i
`if __FILE__ == $PROGRAM_NAME`-blocket. För att använda som bibliotek:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**Förutsättningar:** GNAT (GCC Ada-kompilator)

```bash
cd ada/
gnatmake demo.adb
./demo
```

Paketet är uppdelat i `tdigest.ads` (specifikation), `tdigest.adb` (kropp)
och det generiska 2-3-4-trädpaketet `tree234.ads`/`tree234.adb`.
För att använda i ditt eget projekt, lägg till `with TDigest;` i din källkod och kompilera alla filer tillsammans.

---

## Common Lisp

**Förutsättningar:** SBCL, eller valfri ANSI Common Lisp-implementation

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Interaktiv användning:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**Förutsättningar:** CHICKEN Scheme (`csi`), eller valfri R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Eller med Guile:

```bash
guile demo.scm
```

Obs: Literalerna `+inf.0` och `-inf.0` används för oändlighet. Om din
Scheme-implementation använder andra konstanter kan du behöva justera
definitionerna av `+inf` och `-inf` högst upp i `tdigest.scm`.

---

## Standard ML

**Förutsättningar:** MLton (för kompilering) eller SML/NJ (för interaktiv användning)

**Med MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**Med SML/NJ:**

```bash
cd sml/
sml demo.sml
```

MLB-filen (`demo.mlb`) listar basis-biblioteket och källfiler för
MLtons byggsystem.

---

## Prolog

**Förutsättningar:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

Demon laddar modulen `tdigest` och körs automatiskt via
direktivet `:- initialization(main, main).`.

Interaktiv användning:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**Förutsättningar:** Mercury-kompilator (`mmc`)

**Rent funktionell version** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Muterbar version** (2-3-4-träd med unikhetstyper):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Mercurys byggsystem kompilerar automatiskt beroenden
(`tdigest.m`, `fingertree.m`, `measured_tree234.m` osv.).

---

## C

**Förutsättningar:** GCC eller Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**Förutsättningar:** G++ eller Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**Förutsättningar:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**Förutsättningar:** Cargo och Rust-verktygskedjan

```bash
cd rust/
cargo run --release
```

---

## Java

**Förutsättningar:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**Förutsättningar:** Kotlin-kompilator

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**Förutsättningar:** Python 3 (inga externa beroenden)

```bash
cd python/
python3 demo.py
```

---

## Julia

**Förutsättningar:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**Förutsättningar:** OCaml-kompilator med ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**Förutsättningar:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**Förutsättningar:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**Förutsättningar:** GFortran eller annan Fortran 2003+-kompilator

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**Förutsättningar:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**Förutsättningar:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**Förutsättningar:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**Förutsättningar:** Zig-kompilator

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**Förutsättningar:** Nim-kompilator

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**Förutsättningar:** DMD eller LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**Förutsättningar:** .NET SDK eller Mono

**Med .NET SDK:**

```bash
cd csharp/
dotnet run
```

**Med Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**Förutsättningar:** Swift-kompilator

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
