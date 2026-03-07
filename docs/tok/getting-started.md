# open kepeken t-digest

## ilo ni li wile e seme?

sina wile e ilo ni:
- ilo `git`
- ilo pi toki ilo wan anu mute (o lukin e ni)

## kama jo e lipu mama

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## pali en kepeken lon toki ilo ale

### Haskell

sina wile e ilo `ghc` (ilo pali pi toki Haskell).

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

ilo `TDigest` li kepeken ilo `base` taso. sina wile ala e Cabal anu Stack.

**kepeken lon lipu sina:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

sina wile e ilo `ruby` (nanpa 2.0 anu suli).

```bash
cd ruby/
ruby tdigest.rb
```

lipu `tdigest.rb` li jo e ilo en sitelen pali. sina ken kepeken ona sama ilo taso:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

sina wile e ilo `gnatmake` (ilo pali pi toki Ada lon insa GCC).

```bash
cd ada/
gnatmake demo.adb
./demo
```

ilo li jo e lipu `tdigest.ads` (nasin), `tdigest.adb` (insa), en `tree234.ads`/`tree234.adb` (kasi nanpa).

---

### Common Lisp

sina wile e ilo `sbcl` (Steel Bank Common Lisp).

```bash
cd common-lisp/
sbcl --script demo.lisp
```

kepeken lon toki tawa:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

sina wile e ilo `csi` (CHICKEN Scheme).

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

anu kepeken Guile:

```bash
guile demo.scm
```

sona: `+inf.0` en `-inf.0` li nanpa pi suli ale. ilo Scheme ante li ken kepeken nanpa ante. sina ken ante e `+inf` en `-inf` lon sewi pi lipu `tdigest.scm`.

---

### Standard ML

sina wile e ilo `mlton` (ilo pali MLton) anu ilo `sml` (SML/NJ).

kepeken MLton:

```bash
cd sml/
mlton demo.mlb
./demo
```

kepeken SML/NJ:

```bash
cd sml/
sml demo.sml
```

lipu MLB (`demo.mlb`) li jo e nimi pi lipu ilo ale.

---

### Prolog

sina wile e ilo `swipl` (SWI-Prolog).

```bash
cd prolog/
swipl demo.pl
```

ilo pali li open kepeken `:- initialization(main, main).`.

kepeken lon toki tawa:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

sina wile e ilo `mmc` (ilo pali pi toki Mercury).

**nasin pi ante ala** (kasi luka):

```bash
cd mercury/
mmc --make demo
./demo
```

**nasin pi ante ken** (kasi 2-3-4):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

ilo pali Mercury li pali e ilo ale (`tdigest.m`, `fingertree.m`, `measured_tree234.m`, en ante).

---

### C

sina wile e ilo `gcc` anu `clang`.

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

sina wile e ilo `g++` anu `clang++` (C++17).

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

sina wile e ilo `go` (nanpa 1.18 anu suli).

```bash
cd go/demo
go run .
```

---

### Rust

sina wile e ilo `cargo` en ilo Rust.

```bash
cd rust/
cargo run --release
```

---

### Java

sina wile e JDK (nanpa 11 anu suli).

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

sina wile e ilo pali Kotlin.

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

sina wile e ilo `python3` (wile ala e ilo ante).

```bash
cd python/
python3 demo.py
```

---

### Julia

sina wile e ilo `julia` (nanpa 1.6 anu suli).

```bash
cd julia/
julia demo.jl
```

---

### OCaml

sina wile e ilo pali OCaml en ocamlfind.

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

sina wile e ilo Erlang/OTP.

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

sina wile e ilo `elixir` (nanpa 1.12 anu suli).

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

sina wile e ilo `gfortran` anu ilo pali Fortran 2003+ ante.

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

sina wile e ilo `perl` (Perl 5).

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

sina wile e ilo `lua` (nanpa 5.1 anu suli).

```bash
cd lua/
lua demo.lua
```

---

### R

sina wile e ilo `R` (nanpa 3.0 anu suli).

```bash
cd r/
Rscript demo.R
```

---

### Zig

sina wile e ilo pali Zig.

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

sina wile e ilo pali Nim.

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

sina wile e ilo `dmd` anu `ldc2`.

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

sina wile e .NET SDK anu Mono.

**kepeken .NET SDK:**

```bash
cd csharp/
dotnet run
```

**kepeken Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

sina wile e ilo pali Swift.

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

## ilo ni li pali e seme?

ilo pi toki ilo ale li pali e ni:

1. **pali e t-digest** — nasin pi ante suli li K_1, nanpa delta li 100
2. **pana e nanpa 10000** — nanpa li sama lon 0 tawa 1
3. **toki e sona pi suli pi nanpa** — sona pi nanpa suli 0.1%, 1%, 10%, 25%, 50%, 75%, 90%, 99%, 99.9%
4. **toki e sona CDF** — sona pi mute pi nanpa lon ma
5. **wan e t-digest tu** — pali e t-digest tu, wan e ona, lukin e sona

ilo li toki e ni: sona pi suli pi nanpa, ante pi sona en nanpa lon, mute pi kulupu lili.

## tawa

sina sona e ni la o pali e ilo sina kepeken t-digest!
