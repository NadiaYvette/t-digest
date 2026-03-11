# Sho chô t-digest

## Báq daq lıq bí nä dûe

Dûe jí báq daq lıq:
- `git`
- Báq lıq chuq bí nä pûa báq bangu bí nä chô jí (lûeq báq nîe)

## Kûeq jí báq mama shodaı

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## Chuq bí hóa jáq sho báq bangu rúa

### Haskell

**Hieq:** GHC, `fingertree` ruq `vector` toacuaq

**Gijeq (toacuaq chuo buo):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**Cabal toacuaq buq (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Cabal toacuaq ci toacuaq moq ruo juoq:
`Data.Sketch.TDigest` (ruqshao, finger-tree-huoq) ruq
`Data.Sketch.TDigest.Mutable` (biejuoq, ST monad ruq vector).

**Suq toacuaq deo buq:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

Dûe jí `ruby` (2.0 hóe mıeq).

```bash
cd ruby/
ruby tdigest.rb
```

Báq datnıveı `tdigest.rb` nä jáq sho báq lıq kúe báq demo. Chuq jáq sho báq lıq:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

Dûe jí `gnatmake` (báq Ada chuq lıq jáq sho GCC).

```bash
cd ada/
gnatmake demo.adb
./demo
```

Báq pekıbau nä hóa `tdigest.ads` (tcila), `tdigest.adb` (xadnı), kúe báq `tree234.ads`/`tree234.adb` (2-3-4 treq).

---

### Common Lisp

Dûe jí `sbcl` (Steel Bank Common Lisp).

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Chuq jáq sho báq teq pretı:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

Dûe jí `csi` (CHICKEN Scheme).

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Hóe chuq Guile:

```bash
guile demo.scm
```

Dûa: `+inf.0` kúe `-inf.0` nä hóa báq cımnı namkuq. Báq Scheme daq nä kúe chuq báq drata namkuq.

---

### Standard ML

Dûe jí `mlton` (MLton chuq lıq) hóe `sml` (SML/NJ).

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

Báq MLB datnıveı (`demo.mlb`) nä lıste báq jıcmu lıq kúe báq fonxa datnıveı.

---

### Prolog

Dûe jí `swipl` (SWI-Prolog).

```bash
cd prolog/
swipl demo.pl
```

Báq demo nä cpacu báq `tdigest` modul bí hóa jáq sho `:- initialization(main, main).`.

Chuq jáq sho báq teq pretı:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

Dûe jí `mmc` (báq Mercury chuq lıq).

**Báq junrı fancu muplı** (fıngertree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Báq galfı muplı** (2-3-4 treq):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Báq Mercury chuq cıste nä chuq báq se dûe (`tdigest.m`, `fingertree.m`, `measured_tree234.m`, ktp.).

---

### C

Dûe jí `gcc` hóe `clang`.

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

Dûe jí `g++` hóe `clang++` (C++17).

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

Dûe jí `go` (1.18 hóe mıeq).

```bash
cd go/demo
go run .
```

---

### Rust

Dûe jí `cargo` kúe báq Rust lıq.

```bash
cd rust/
cargo run --release
```

---

### Java

Dûe jí JDK (11 hóe mıeq).

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

Dûe jí báq Kotlin chuq lıq.

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

Dûe jí `python3` (dûe aq jí báq drata lıq).

```bash
cd python/
python3 demo.py
```

---

### Julia

Dûe jí `julia` (1.6 hóe mıeq).

```bash
cd julia/
julia demo.jl
```

---

### OCaml

Dûe jí báq OCaml chuq lıq kúe ocamlfind.

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

Dûe jí Erlang/OTP.

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

Dûe jí `elixir` (1.12 hóe mıeq).

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

Dûe jí `gfortran` hóe báq drata Fortran 2003+ chuq lıq.

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

Dûe jí `perl` (Perl 5).

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

Dûe jí `lua` (5.1 hóe mıeq).

```bash
cd lua/
lua demo.lua
```

---

### R

Dûe jí `R` (3.0 hóe mıeq).

```bash
cd r/
Rscript demo.R
```

---

### Zig

Dûe jí báq Zig chuq lıq.

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

Dûe jí báq Nim chuq lıq.

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

Dûe jí `dmd` hóe `ldc2`.

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

Dûe jí .NET SDK hóe Mono.

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

Dûe jí báq Swift chuq lıq.

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

## Hı raı bı nä hóa moq?

Báq demo rúa nä hóa hóq:

1. **Chuq báq t-digest** — scale functıon nä K_1, delta nä 100
2. **Pûeq báq namkuq 10000** — báq namkuq nä kuq jáq sho 0 taq 1
3. **Dûa báq quantıle** — dûa báq quantıle jáq sho 0.1%, 1%, 10%, 25%, 50%, 75%, 90%, 99%, 99.9%
4. **Dûa báq CDF** — dûa báq CDF jáq sho báq namkuq
5. **Merge báq t-digest fıeq** — chuq báq t-digest fıeq, merge, dûa báq satcı

Báq demo nä kuq: báq quantıle urdalöxha, báq eraq, báq centroıd mute.

## Kue

Chô jí báq lıq suaq la nä chuq t-digest jáq sho báq dataq suaq!
