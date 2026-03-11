# Primii pași

Fiecare implementare într-un limbaj este independentă și se află în propriul director.
Nu există dependențe între limbaje.

---

## Haskell

**Cerinte preliminare:** GHC, pachetele `fingertree` si `vector`

**Independent (fara instrument de constructie):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**Ca pachet Cabal (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Pachetul Cabal expune doua module de biblioteca:
`Data.Sketch.TDigest` (pur, bazat pe finger tree) si
`Data.Sketch.TDigest.Mutable` (mutabil, monada ST cu vectori).

**Utilizare in propriul cod:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**Cerințe:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

Fișierul `tdigest.rb` conține atât biblioteca, cât și un demo în blocul
`if __FILE__ == $PROGRAM_NAME`. Pentru a-l folosi ca bibliotecă:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**Cerințe:** GNAT (compilator GCC Ada)

```bash
cd ada/
gnatmake demo.adb
./demo
```

Pachetul este împărțit în `tdigest.ads` (specificație), `tdigest.adb` (corp)
și pachetul generic de arbore 2-3-4 `tree234.ads`/`tree234.adb`.
Pentru a-l folosi în propriul proiect, adăugați `with TDigest;` în codul sursă și compilați toate fișierele împreună.

---

## Common Lisp

**Cerințe:** SBCL sau orice implementare ANSI Common Lisp

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Utilizare interactivă:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**Cerințe:** CHICKEN Scheme (`csi`) sau orice implementare R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Sau cu Guile:

```bash
guile demo.scm
```

Notă: se folosesc literalele `+inf.0` și `-inf.0` pentru infinit. Dacă
implementarea dvs. de Scheme folosește alte constante, poate fi necesar să ajustați
definițiile `+inf` și `-inf` din partea de sus a fișierului `tdigest.scm`.

---

## Standard ML

**Cerințe:** MLton (pentru compilare) sau SML/NJ (pentru utilizare interactivă)

**Cu MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**Cu SML/NJ:**

```bash
cd sml/
sml demo.sml
```

Fișierul MLB (`demo.mlb`) listează biblioteca basis și fișierele sursă pentru
sistemul de construire MLton.

---

## Prolog

**Cerințe:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

Demo-ul încarcă modulul `tdigest` și se execută automat prin
directiva `:- initialization(main, main).`.

Utilizare interactivă:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**Cerințe:** compilatorul Mercury (`mmc`)

**Versiune pur funcțională** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Versiune mutabilă** (arbore 2-3-4 cu tipuri de unicitate):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Sistemul de construire Mercury va compila automat dependențele
(`tdigest.m`, `fingertree.m`, `measured_tree234.m` etc.).

---

## C

**Cerințe:** GCC sau Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**Cerințe:** G++ sau Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**Cerințe:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**Cerințe:** Cargo și toolchain-ul Rust

```bash
cd rust/
cargo run --release
```

---

## Java

**Cerințe:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**Cerințe:** compilatorul Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**Cerințe:** Python 3 (fără dependențe externe)

```bash
cd python/
python3 demo.py
```

---

## Julia

**Cerințe:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**Cerințe:** compilatorul OCaml cu ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**Cerințe:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**Cerințe:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**Cerințe:** GFortran sau alt compilator Fortran 2003+

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**Cerințe:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**Cerințe:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**Cerințe:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**Cerințe:** compilatorul Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**Cerințe:** compilatorul Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**Cerințe:** DMD sau LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**Cerințe:** .NET SDK sau Mono

**Cu .NET SDK:**

```bash
cd csharp/
dotnet run
```

**Cu Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**Cerințe:** compilatorul Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
