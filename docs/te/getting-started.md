# ప్రారంభించండి

## ముందస్తు అవసరాలు

t-digest భాండాగారంలో 28 ప్రోగ్రామింగ్ భాషలలో అమలు ఉంది. ప్రతిదాన్ని నడపడానికి సంబంధిత భాష యొక్క కంపైలర్ లేదా ఇంటర్‌ప్రెటర్ ఇన్‌స్టాల్ చేయబడి ఉండాలి.

```bash
# భాండాగారం క్లోన్ చేయండి
git clone <repository-url>
cd t-digest
```

## Haskell

**ముందస్తు అవసరాలు:** GHC, `fingertree` మరియు `vector` ప్యాకేజీలు

**స్వతంత్రంగా (బిల్డ్ టూల్ లేకుండా):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**Cabal ప్యాకేజీగా (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Cabal ప్యాకేజీ రెండు లైబ్రరీ మాడ్యూల్‌లను బహిర్గతం చేస్తుంది:
`Data.Sketch.TDigest` (స్వచ్ఛమైన, ఫింగర్-ట్రీ-ఆధారిత) మరియు
`Data.Sketch.TDigest.Mutable` (మార్పు చేయగల, వెక్టార్‌లతో ST మొనాడ్).

**మీ స్వంత కోడ్‌లో ఉపయోగించడం:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

## Ruby

Ruby అమలుకు బాహ్య లైబ్రరీలు అవసరం లేదు. ప్రదర్శన నడపడానికి:

```bash
cd ruby/
ruby tdigest.rb
```

## Ada

Ada అమలు GNAT కంపైలర్ ఉపయోగిస్తుంది:

```bash
cd ada/
gnatmake demo.adb
./demo
```

## Common Lisp

Common Lisp అమలు SBCL ఇంటర్‌ప్రెటర్ ఉపయోగిస్తుంది:

```bash
cd common-lisp/
sbcl --script demo.lisp
```

## Scheme

Scheme అమలు CHICKEN Scheme (csi) ఇంటర్‌ప్రెటర్‌తో R5RS ప్రమాణం ఉపయోగిస్తుంది:

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

లేదా Guile తో:

```bash
guile demo.scm
```

## Standard ML

Standard ML అమలు MLton కంపైలర్ ఉపయోగిస్తుంది:

**MLton తో:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**SML/NJ తో:**

```bash
cd sml/
sml demo.sml
```

## Prolog

Prolog అమలు SWI-Prolog ఇంటర్‌ప్రెటర్ ఉపయోగిస్తుంది:

```bash
cd prolog/
swipl demo.pl
```

## Mercury

Mercury అమలు Melbourne Mercury కంపైలర్ ఉపయోగిస్తుంది:

**స్వచ్ఛ ఫంక్షనల్ వెర్షన్** (ఫింగర్ ట్రీ):

```bash
cd mercury/
mmc --make demo
./demo
```

**మ్యూటబుల్ వెర్షన్** (2-3-4 ట్రీ, యూనిక్‌నెస్ టైప్‌లతో):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

---

## C

**ముందస్తు అవసరాలు:** GCC లేదా Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**ముందస్తు అవసరాలు:** G++ లేదా Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**ముందస్తు అవసరాలు:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**ముందస్తు అవసరాలు:** Cargo మరియు Rust టూల్‌చైన్

```bash
cd rust/
cargo run --release
```

---

## Java

**ముందస్తు అవసరాలు:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**ముందస్తు అవసరాలు:** Kotlin కంపైలర్

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**ముందస్తు అవసరాలు:** Python 3 (బాహ్య డిపెండెన్సీలు లేవు)

```bash
cd python/
python3 demo.py
```

---

## Julia

**ముందస్తు అవసరాలు:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**ముందస్తు అవసరాలు:** OCaml కంపైలర్ మరియు ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**ముందస్తు అవసరాలు:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**ముందస్తు అవసరాలు:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**ముందస్తు అవసరాలు:** GFortran లేదా ఇతర Fortran 2003+ కంపైలర్

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**ముందస్తు అవసరాలు:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**ముందస్తు అవసరాలు:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**ముందస్తు అవసరాలు:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**ముందస్తు అవసరాలు:** Zig కంపైలర్

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**ముందస్తు అవసరాలు:** Nim కంపైలర్

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**ముందస్తు అవసరాలు:** DMD లేదా LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**ముందస్తు అవసరాలు:** .NET SDK లేదా Mono

**.NET SDK తో:**

```bash
cd csharp/
dotnet run
```

**Mono తో:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**ముందస్తు అవసరాలు:** Swift కంపైలర్

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

---

## సాధారణ సమస్యా పరిష్కారం

- **కంపైలర్ కనుగొనబడలేదు** — సంబంధిత భాష యొక్క కంపైలర్ లేదా ఇంటర్‌ప్రెటర్ మీ PATH లో ఉందని నిర్ధారించుకోండి
- **కంపైల్ దోషం** — మీరు సరైన డైరెక్టరీలో ఉన్నారో లేదో తనిఖీ చేయండి (`cd <భాష>`)
- **అనుమతి నిరాకరించబడింది** — కంపైల్ చేసిన బైనరీకి అమలు అనుమతి ఇవ్వండి: `chmod +x demo`
