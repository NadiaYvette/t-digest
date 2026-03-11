# ਸ਼ੁਰੂਆਤ ਕਰੋ

## ਪੂਰਵ-ਲੋੜਾਂ

t-digest ਭੰਡਾਰ ਵਿੱਚ 28 ਪ੍ਰੋਗ੍ਰਾਮਿੰਗ ਭਾਸ਼ਾਵਾਂ ਵਿੱਚ ਅਮਲ ਹੈ। ਹਰੇਕ ਨੂੰ ਚਲਾਉਣ ਲਈ ਸੰਬੰਧਿਤ ਭਾਸ਼ਾ ਦਾ ਕੰਪਾਈਲਰ ਜਾਂ ਦੁਭਾਸ਼ੀਆ ਸਥਾਪਿਤ ਹੋਣਾ ਚਾਹੀਦਾ ਹੈ।

```bash
# ਭੰਡਾਰ ਕਲੋਨ ਕਰੋ
git clone <repository-url>
cd t-digest
```

## Haskell

**ਪੂਰਵ-ਲੋੜਾਂ:** GHC, `fingertree` ਅਤੇ `vector` ਪੈਕੇਜ

**ਸੁਤੰਤਰ (ਬਿਨਾਂ ਬਿਲਡ ਟੂਲ):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**Cabal ਪੈਕੇਜ ਵਜੋਂ (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Cabal ਪੈਕੇਜ ਦੋ ਲਾਇਬ੍ਰੇਰੀ ਮੋਡੀਊਲ ਪ੍ਰਦਾਨ ਕਰਦਾ ਹੈ:
`Data.Sketch.TDigest` (ਸ਼ੁੱਧ, ਫਿੰਗਰ-ਟ੍ਰੀ-ਅਧਾਰਿਤ) ਅਤੇ
`Data.Sketch.TDigest.Mutable` (ਪਰਿਵਰਤਨਸ਼ੀਲ, ਵੈਕਟਰਾਂ ਨਾਲ ST ਮੋਨੈਡ)।

**ਆਪਣੇ ਕੋਡ ਵਿੱਚ ਵਰਤੋਂ:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**ਪੂਰਵ-ਲੋੜਾਂ:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

ਫ਼ਾਈਲ `tdigest.rb` ਵਿੱਚ ਲਾਇਬ੍ਰੇਰੀ ਅਤੇ ਪ੍ਰਦਰਸ਼ਨ ਦੋਵੇਂ `if __FILE__ == $PROGRAM_NAME` ਬਲਾਕ ਵਿੱਚ ਹਨ। ਲਾਇਬ੍ਰੇਰੀ ਵਜੋਂ ਵਰਤਣ ਲਈ:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**ਪੂਰਵ-ਲੋੜਾਂ:** GNAT (GNU Ada ਕੰਪਾਈਲਰ)

```bash
cd ada/
gnatmake demo.adb
./demo
```

---

## Common Lisp

**ਪੂਰਵ-ਲੋੜਾਂ:** SBCL, ਜਾਂ ਕੋਈ ANSI Common Lisp ਅਮਲ

```bash
cd common-lisp/
sbcl --script demo.lisp
```

ਇੰਟਰੈਕਟਿਵ ਵਰਤੋਂ ਲਈ:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**ਪੂਰਵ-ਲੋੜਾਂ:** CHICKEN Scheme (`csi`), ਜਾਂ ਕੋਈ R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

ਜਾਂ Guile ਨਾਲ:

```bash
guile demo.scm
```

---

## Standard ML

**ਪੂਰਵ-ਲੋੜਾਂ:** MLton (ਕੰਪਾਈਲ ਲਈ) ਜਾਂ SML/NJ (ਇੰਟਰੈਕਟਿਵ ਵਰਤੋਂ ਲਈ)

**MLton ਨਾਲ:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**SML/NJ ਨਾਲ:**

```bash
cd sml/
sml demo.sml
```

---

## Prolog

**ਪੂਰਵ-ਲੋੜਾਂ:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

ਇੰਟਰੈਕਟਿਵ ਵਰਤੋਂ ਲਈ:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**ਪੂਰਵ-ਲੋੜਾਂ:** Mercury ਕੰਪਾਈਲਰ (`mmc`)

**ਸ਼ੁੱਧ ਫੰਕਸ਼ਨਲ ਸੰਸਕਰਣ** (ਫਿੰਗਰ ਟ੍ਰੀ):

```bash
cd mercury/
mmc --make demo
./demo
```

**ਪਰਿਵਰਤਨਸ਼ੀਲ ਸੰਸਕਰਣ** (2-3-4 ਟ੍ਰੀ ਨਾਲ ਵਿਲੱਖਣਤਾ ਕਿਸਮਾਂ):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

---

## C

**ਪੂਰਵ-ਲੋੜਾਂ:** GCC ਜਾਂ Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**ਪੂਰਵ-ਲੋੜਾਂ:** G++ ਜਾਂ Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**ਪੂਰਵ-ਲੋੜਾਂ:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**ਪੂਰਵ-ਲੋੜਾਂ:** Cargo ਅਤੇ Rust ਟੂਲ ਚੇਨ

```bash
cd rust/
cargo run --release
```

---

## Java

**ਪੂਰਵ-ਲੋੜਾਂ:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**ਪੂਰਵ-ਲੋੜਾਂ:** Kotlin ਕੰਪਾਈਲਰ

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**ਪੂਰਵ-ਲੋੜਾਂ:** Python 3 (ਕੋਈ ਬਾਹਰੀ ਨਿਰਭਰਤਾ ਨਹੀਂ)

```bash
cd python/
python3 demo.py
```

---

## Julia

**ਪੂਰਵ-ਲੋੜਾਂ:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**ਪੂਰਵ-ਲੋੜਾਂ:** OCaml ਕੰਪਾਈਲਰ ਨਾਲ ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**ਪੂਰਵ-ਲੋੜਾਂ:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**ਪੂਰਵ-ਲੋੜਾਂ:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**ਪੂਰਵ-ਲੋੜਾਂ:** GFortran ਜਾਂ ਕੋਈ Fortran 2003+ ਕੰਪਾਈਲਰ

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**ਪੂਰਵ-ਲੋੜਾਂ:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**ਪੂਰਵ-ਲੋੜਾਂ:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**ਪੂਰਵ-ਲੋੜਾਂ:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**ਪੂਰਵ-ਲੋੜਾਂ:** Zig ਕੰਪਾਈਲਰ

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**ਪੂਰਵ-ਲੋੜਾਂ:** Nim ਕੰਪਾਈਲਰ

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**ਪੂਰਵ-ਲੋੜਾਂ:** DMD ਜਾਂ LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**ਪੂਰਵ-ਲੋੜਾਂ:** .NET SDK ਜਾਂ Mono

**.NET SDK ਨਾਲ:**

```bash
cd csharp/
dotnet run
```

**Mono ਨਾਲ:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**ਪੂਰਵ-ਲੋੜਾਂ:** Swift ਕੰਪਾਈਲਰ

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

## ਆਮ ਸਮੱਸਿਆ-ਨਿਵਾਰਨ

- **ਕੰਪਾਈਲਰ ਨਹੀਂ ਮਿਲਿਆ** — ਯਕੀਨੀ ਬਣਾਓ ਕਿ ਸੰਬੰਧਿਤ ਭਾਸ਼ਾ ਦਾ ਕੰਪਾਈਲਰ ਜਾਂ ਦੁਭਾਸ਼ੀਆ ਤੁਹਾਡੇ PATH ਵਿੱਚ ਹੈ
- **ਕੰਪਾਈਲ ਗ਼ਲਤੀ** — ਜਾਂਚੋ ਕਿ ਤੁਸੀਂ ਸਹੀ ਡਾਇਰੈਕਟਰੀ ਵਿੱਚ ਹੋ (`cd <ਭਾਸ਼ਾ>`)
- **ਇਜਾਜ਼ਤ ਤੋਂ ਇਨਕਾਰ** — ਕੰਪਾਈਲ ਕੀਤੀ ਬਾਈਨਰੀ ਨੂੰ ਚਲਾਉਣ ਦੀ ਇਜਾਜ਼ਤ ਦਿਓ: `chmod +x demo`
