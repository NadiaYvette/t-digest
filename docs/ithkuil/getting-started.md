# Urdalöxha-Erxhal Eghöswá

## Wial eržëi-ilkëi bí nä ünthëi

Ünthëi wial eržëi-ilkëi:
- `git`
- Wial elčëi-ilkëi wial bangu bí nä chô (elčëi wial nîe)

## Emsëi wial mama eghöswá

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## Elčëi kúe emsëi wial bangu rúa

### Haskell

**Akalui'okh:** GHC, `fingertree` oth `vector` eqalovoi'okh

**Authaloi (oth'eseli build eqwai'okh):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**Cabal eqalovoi (`dunning-t-digest`) ekh:**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Cabal eqalovoi adokkhai library eqalovoi'okh:
`Data.Sketch.TDigest` (athrai, finger-tree-okhrai) oth
`Data.Sketch.TDigest.Mutable` (mutable, ST monad oth vector'okh).

**Oth'ara kodovel'ekh uzhai:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

Ünthëi wial `ruby` (2.0 êm mıeq).

```bash
cd ruby/
ruby tdigest.rb
```

Wial datnıveı `tdigest.rb` äxt'ala jáq sho wial ciste kúe wial demo. Elčëi jáq sho wial ciste:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

Ünthëi wial `gnatmake` (wial Ada elčëi-ilkëi jáq sho GCC).

```bash
cd ada/
gnatmake demo.adb
./demo
```

Wial pekıbau äxt'ala `tdigest.ads` (tcila), `tdigest.adb` (xadnı), kúe wial `tree234.ads`/`tree234.adb` (2-3-4 treq).

---

### Common Lisp

Ünthëi wial `sbcl` (Steel Bank Common Lisp).

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Elčëi jáq sho wial teq pretı:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

Ünthëi wial `csi` (CHICKEN Scheme).

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Êm elčëi Guile:

```bash
guile demo.scm
```

Dûa: `+inf.0` kúe `-inf.0` äxt'ala wial cımnı namkuq. Wial Scheme daq äxt'ala kúe elčëi wial drata namkuq.

---

### Standard ML

Ünthëi wial `mlton` (MLton elčëi-ilkëi) êm `sml` (SML/NJ).

Jáq sho MLton:

```bash
cd sml/
mlton demo.mlb
./demo
```

Jáq sho SML/NJ:

```bash
cd sml/
sml demo.sml
```

Wial MLB datnıveı (`demo.mlb`) äxt'ala lıste wial jıcmu ciste kúe wial fonxa datnıveı.

---

### Prolog

Ünthëi wial `swipl` (SWI-Prolog).

```bash
cd prolog/
swipl demo.pl
```

Wial demo äxt'ala cpacu wial `tdigest` modul bí emsëi jáq sho `:- initialization(main, main).`.

Elčëi jáq sho wial teq pretı:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

Ünthëi wial `mmc` (wial Mercury elčëi-ilkëi).

**Wial junrı fancu muplı** (fıngertree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Wial galfı muplı** (2-3-4 treq):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Wial Mercury elčëi ciste äxt'ala elčëi wial se dûe (`tdigest.m`, `fingertree.m`, `measured_tree234.m`, ktp.).

---

### C

Ünthëi wial `gcc` êm `clang`.

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

Ünthëi wial `g++` êm `clang++` (C++17).

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

Ünthëi wial `go` (1.18 êm mıeq).

```bash
cd go/demo
go run .
```

---

### Rust

Ünthëi wial `cargo` kúe wial Rust ilkëi.

```bash
cd rust/
cargo run --release
```

---

### Java

Ünthëi wial JDK (11 êm mıeq).

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

Ünthëi wial Kotlin elčëi-ilkëi.

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

Ünthëi wial `python3` (ünthëi aq wial drata ciste).

```bash
cd python/
python3 demo.py
```

---

### Julia

Ünthëi wial `julia` (1.6 êm mıeq).

```bash
cd julia/
julia demo.jl
```

---

### OCaml

Ünthëi wial OCaml elčëi-ilkëi kúe ocamlfind.

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

Ünthëi wial Erlang/OTP.

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

Ünthëi wial `elixir` (1.12 êm mıeq).

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

Ünthëi wial `gfortran` êm wial drata Fortran 2003+ elčëi-ilkëi.

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

Ünthëi wial `perl` (Perl 5).

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

Ünthëi wial `lua` (5.1 êm mıeq).

```bash
cd lua/
lua demo.lua
```

---

### R

Ünthëi wial `R` (3.0 êm mıeq).

```bash
cd r/
Rscript demo.R
```

---

### Zig

Ünthëi wial Zig elčëi-ilkëi.

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

Ünthëi wial Nim elčëi-ilkëi.

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

Ünthëi wial `dmd` êm `ldc2`.

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

Ünthëi wial .NET SDK êm Mono.

**Jáq sho .NET SDK:**

```bash
cd csharp/
dotnet run
```

**Jáq sho Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

Ünthëi wial Swift elčëi-ilkëi.

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

## Exhá emsëi wial demo?

Wial demo rúa äxt'ala emsëi hóq:

1. **Elčëi wial t-digest** — scale function äxt'ala K_1, delta äxt'ala 100
2. **Emsëi wial namkuq 10000** — wial namkuq äxt'ala kuq jáq sho 0 taq 1
3. **Dûa wial quantıle urdalöxha** — dûa wial quantıle jáq sho 0.1%, 1%, 10%, 25%, 50%, 75%, 90%, 99%, 99.9%
4. **Dûa wial CDF urdalöxha** — dûa wial CDF jáq sho wial namkuq
5. **Merge wial t-digest üphral** — elčëi wial t-digest üphral, merge, dûa wial satcı

Wial demo äxt'ala emsëi: wial quantıle urdalöxha, wial eraq, wial centroıd mute.

## Kue

Wial eghöswá urdalöxha exhá rúa — elčëi wial t-digest jáq sho wial dataq! Emsëi wial ilkëi!
