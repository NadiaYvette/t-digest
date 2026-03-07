# Aan de slag

Dit project bevat t-digest-implementaties in 28 programmeertalen. Elke implementatie gebruikt de merging-digest-variant met de K_1-schaalfunctie (arcsinus).

## Compileren en uitvoeren

### Haskell

**Vereisten:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

De module `TDigest` gebruikt alleen `base`-bibliotheken (geen Cabal- of Stack-project vereist).

**Gebruik in uw eigen code:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

**Vereisten:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

Het bestand `tdigest.rb` bevat zowel de bibliotheek als een demo in het `if __FILE__ == $PROGRAM_NAME`-blok. Om het als bibliotheek te gebruiken:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

**Vereisten:** GNAT (GCC Ada-compiler)

```bash
cd ada/
gnatmake demo.adb
./demo
```

Het pakket is opgedeeld in `tdigest.ads` (specificatie), `tdigest.adb` (body) en het generieke 2-3-4-boom-pakket `tree234.ads`/`tree234.adb`. Om het in uw eigen project te gebruiken, voegt u `with TDigest;` toe in uw broncode en compileert u alle bestanden samen.

---

### Common Lisp

**Vereisten:** SBCL of elke ANSI Common Lisp-implementatie

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Voor interactief gebruik:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

**Vereisten:** CHICKEN Scheme (`csi`) of elk R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Of met Guile:

```bash
guile demo.scm
```

Opmerking: De literalen `+inf.0` en `-inf.0` worden gebruikt voor oneindigheid. Als uw Scheme-implementatie andere constanten gebruikt, moet u mogelijk de definities van `+inf` en `-inf` bovenaan `tdigest.scm` aanpassen.

---

### Standard ML

**Vereisten:** MLton (voor compilatie) of SML/NJ (voor interactief gebruik)

**Met MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**Met SML/NJ:**

```bash
cd sml/
sml demo.sml
```

Het MLB-bestand (`demo.mlb`) bevat de basisbibliotheek en bronbestanden voor het buildsysteem van MLton.

---

### Prolog

**Vereisten:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

De demo laadt de `tdigest`-module en wordt automatisch uitgevoerd via de `:- initialization(main, main).`-directive.

Voor interactief gebruik:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

**Vereisten:** Mercury-compiler (`mmc`)

**Puur functionele versie** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Muteerbare versie** (2-3-4-boom met uniqueness-typen):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Het Mercury-buildsysteem compileert automatisch afhankelijkheden (`tdigest.m`, `fingertree.m`, `measured_tree234.m`, enz.).

---

### C

**Vereisten:** GCC of Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

**Vereisten:** G++ of Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

**Vereisten:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

### Rust

**Vereisten:** Cargo en Rust-toolchain

```bash
cd rust/
cargo run --release
```

---

### Java

**Vereisten:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

**Vereisten:** Kotlin-compiler

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

**Vereisten:** Python 3 (geen externe afhankelijkheden)

```bash
cd python/
python3 demo.py
```

---

### Julia

**Vereisten:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

### OCaml

**Vereisten:** OCaml-compiler met ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

**Vereisten:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

**Vereisten:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

**Vereisten:** GFortran of een andere Fortran 2003+-compiler

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

**Vereisten:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

**Vereisten:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

### R

**Vereisten:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

### Zig

**Vereisten:** Zig-compiler

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

**Vereisten:** Nim-compiler

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

**Vereisten:** DMD of LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

**Vereisten:** .NET SDK of Mono

**Met .NET SDK:**

```bash
cd csharp/
dotnet run
```

**Met Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

**Vereisten:** Swift-compiler

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
