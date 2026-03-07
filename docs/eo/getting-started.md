# Unuaj paŝoj

Ĉi tiu projekto enhavas realigojn de t-digest en 28 programlingvoj. Ĉiu realigo uzas la variaĵon merging digest kun la skalfunkcio K_1 (arksinuso).

## Kompili kaj ruli

### Haskell

**Antaŭkondiĉoj:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

La modulo `TDigest` uzas nur `base`-bibliotekojn (neniu Cabal- aŭ Stack-projekto necesas).

**Uzado en via propra kodo:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

**Antaŭkondiĉoj:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

La dosiero `tdigest.rb` enhavas ambaŭ la bibliotekon kaj demonstraĵon en la bloko `if __FILE__ == $PROGRAM_NAME`. Por uzi ĝin kiel bibliotekon:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

**Antaŭkondiĉoj:** GNAT (GCC Ada-kompililo)

```bash
cd ada/
gnatmake demo.adb
./demo
```

La pako konsistas el `tdigest.ads` (specifo), `tdigest.adb` (korpo), kaj la ĝenerala `tree234.ads`/`tree234.adb` 2-3-4-arba pako. Por uzi en via propra projekto, aldonu `with TDigest;` en via fontkodo kaj kompilu ĉiujn dosierojn kune.

---

### Common Lisp

**Antaŭkondiĉoj:** SBCL, aŭ iu ajn ANSI Common Lisp realigo

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Por uzi interaktive:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

**Antaŭkondiĉoj:** CHICKEN Scheme (`csi`), aŭ iu ajn R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Aŭ per Guile:

```bash
guile demo.scm
```

Noto: La literaloj `+inf.0` kaj `-inf.0` estas uzataj por malfinio. Se via Scheme-realigo uzas aliajn konstantojn, vi eble bezonos ĝustigi la difinojn de `+inf` kaj `-inf` ĉe la supro de `tdigest.scm`.

---

### Standard ML

**Antaŭkondiĉoj:** MLton (por kompilado) aŭ SML/NJ (por interaktiva uzo)

**Per MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**Per SML/NJ:**

```bash
cd sml/
sml demo.sml
```

La MLB-dosiero (`demo.mlb`) listigas la bazan bibliotekon kaj fontdosierojn por la konstrua sistemo de MLton.

---

### Prolog

**Antaŭkondiĉoj:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

La demonstraĵo ŝargas la modulon `tdigest` kaj funkcias aŭtomate per la direktivo `:- initialization(main, main).`.

Por uzi interaktive:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

**Antaŭkondiĉoj:** Mercury-kompililo (`mmc`)

**Pure funkcia versio** (fingroarbo):

```bash
cd mercury/
mmc --make demo
./demo
```

**Ŝanĝebla versio** (2-3-4-arbo kun unikecaj tipoj):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

La Mercury-konstrua sistemo aŭtomate kompilos dependecojn (`tdigest.m`, `fingertree.m`, `measured_tree234.m`, ktp.).

---

### C

**Antaŭkondiĉoj:** GCC aŭ Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

**Antaŭkondiĉoj:** G++ aŭ Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

**Antaŭkondiĉoj:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

### Rust

**Antaŭkondiĉoj:** Cargo kaj Rust-ilaĉeno

```bash
cd rust/
cargo run --release
```

---

### Java

**Antaŭkondiĉoj:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

**Antaŭkondiĉoj:** Kotlin-kompililo

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

**Antaŭkondiĉoj:** Python 3 (neniuj eksteraj dependecoj)

```bash
cd python/
python3 demo.py
```

---

### Julia

**Antaŭkondiĉoj:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

### OCaml

**Antaŭkondiĉoj:** OCaml-kompililo kun ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

**Antaŭkondiĉoj:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

**Antaŭkondiĉoj:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

**Antaŭkondiĉoj:** GFortran aŭ alia Fortran 2003+ kompililo

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

**Antaŭkondiĉoj:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

**Antaŭkondiĉoj:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

### R

**Antaŭkondiĉoj:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

### Zig

**Antaŭkondiĉoj:** Zig-kompililo

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

**Antaŭkondiĉoj:** Nim-kompililo

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

**Antaŭkondiĉoj:** DMD aŭ LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

**Antaŭkondiĉoj:** .NET SDK aŭ Mono

**Per .NET SDK:**

```bash
cd csharp/
dotnet run
```

**Per Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

**Antaŭkondiĉoj:** Swift-kompililo

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
