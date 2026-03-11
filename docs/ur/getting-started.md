# آغاز کریں

## پیش شرائط

t-digest ذخیرے میں 28 پروگرامنگ زبانوں میں عمل درآمد موجود ہے۔ ہر ایک کو چلانے کے لیے متعلقہ زبان کا مرتب ساز (compiler) یا مترجم (interpreter) نصب ہونا ضروری ہے۔

```bash
# ذخیرہ کلون کریں
git clone <repository-url>
cd t-digest
```

## Haskell

**لوازمات:** GHC، `fingertree` اور `vector` پیکیجز

**خودمختار (بلڈ ٹول کے بغیر):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**Cabal پیکیج کے طور پر (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Cabal پیکیج دو لائبریری ماڈیولز فراہم کرتا ہے:
`Data.Sketch.TDigest` (خالص، فنگر ٹری پر مبنی) اور
`Data.Sketch.TDigest.Mutable` (قابل تبدیل، ویکٹرز کے ساتھ ST موناڈ)۔

**اپنے کوڈ میں استعمال:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**پیش شرائط:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

فائل `tdigest.rb` میں کتب خانہ اور مظاہرہ دونوں `if __FILE__ == $PROGRAM_NAME` بلاک میں موجود ہیں۔ کتب خانے کے طور پر استعمال کے لیے:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**پیش شرائط:** GNAT (GNU Ada مرتب ساز)

```bash
cd ada/
gnatmake demo.adb
./demo
```

---

## Common Lisp

**پیش شرائط:** SBCL، یا کوئی ANSI Common Lisp عمل درآمد

```bash
cd common-lisp/
sbcl --script demo.lisp
```

تعاملی استعمال کے لیے:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**پیش شرائط:** CHICKEN Scheme (`csi`)، یا کوئی R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

یا Guile کے ساتھ:

```bash
guile demo.scm
```

---

## Standard ML

**پیش شرائط:** MLton (ترتیب کے لیے) یا SML/NJ (تعاملی استعمال کے لیے)

**MLton کے ساتھ:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**SML/NJ کے ساتھ:**

```bash
cd sml/
sml demo.sml
```

---

## Prolog

**پیش شرائط:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

تعاملی استعمال کے لیے:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**پیش شرائط:** Mercury مرتب ساز (`mmc`)

**خالص فنکشنل نسخہ** (فنگر ٹری):

```bash
cd mercury/
mmc --make demo
./demo
```

**تبدیلی پذیر نسخہ** (2-3-4 ٹری بمع یکتائی اقسام):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

---

## C

**پیش شرائط:** GCC یا Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**پیش شرائط:** G++ یا Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**پیش شرائط:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**پیش شرائط:** Cargo اور Rust ٹول چین

```bash
cd rust/
cargo run --release
```

---

## Java

**پیش شرائط:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**پیش شرائط:** Kotlin مرتب ساز

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**پیش شرائط:** Python 3 (کوئی بیرونی انحصار نہیں)

```bash
cd python/
python3 demo.py
```

---

## Julia

**پیش شرائط:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**پیش شرائط:** OCaml مرتب ساز بمع ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**پیش شرائط:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**پیش شرائط:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**پیش شرائط:** GFortran یا کوئی Fortran 2003+ مرتب ساز

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**پیش شرائط:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**پیش شرائط:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**پیش شرائط:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**پیش شرائط:** Zig مرتب ساز

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**پیش شرائط:** Nim مرتب ساز

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**پیش شرائط:** DMD یا LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**پیش شرائط:** .NET SDK یا Mono

**.NET SDK کے ساتھ:**

```bash
cd csharp/
dotnet run
```

**Mono کے ساتھ:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**پیش شرائط:** Swift مرتب ساز

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

## عام مسائل کا حل

- **مرتب ساز نہیں ملا** — یقینی بنائیں کہ متعلقہ زبان کا مرتب ساز یا مترجم آپ کے PATH میں ہے
- **ترتیب میں خرابی** — جانچیں کہ آپ صحیح ڈائریکٹری میں ہیں (`cd <زبان>`)
- **اجازت سے انکار** — مرتب شدہ بائنری کو چلانے کی اجازت دیں: `chmod +x demo`
