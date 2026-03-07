# Hızlı Başlangıç

Her dildeki uygulama kendi dizininde bağımsız olarak yer almaktadır.
Diller arası bağımlılık yoktur.

---

## Haskell

**Gereksinimler:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

`TDigest` modülü yalnızca `base` kütüphanelerini kullanır (Cabal veya Stack projesi gerekmez).

**Kendi kodunuzda kullanım:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**Gereksinimler:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

`tdigest.rb` dosyası hem kütüphaneyi hem de `if __FILE__ == $PROGRAM_NAME`
bloğundaki demoyu içerir. Kütüphane olarak kullanmak için:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**Gereksinimler:** GNAT (GCC Ada derleyicisi)

```bash
cd ada/
gnatmake demo.adb
./demo
```

Paket `tdigest.ads` (spec), `tdigest.adb` (gövde) ve genel 2-3-4 ağacı
paketi `tree234.ads`/`tree234.adb` olarak ayrılmıştır. Kendi projenizde
kullanmak için kaynak kodunuza `with TDigest;` ekleyin ve tüm dosyaları birlikte derleyin.

---

## Common Lisp

**Gereksinimler:** SBCL veya herhangi bir ANSI Common Lisp uygulaması

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Etkileşimli kullanım:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**Gereksinimler:** CHICKEN Scheme (`csi`) veya herhangi bir R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Veya Guile ile:

```bash
guile demo.scm
```

Not: Sonsuzluk için `+inf.0` ve `-inf.0` literalleri kullanılmaktadır. Scheme
uygulamanız farklı sabitler kullanıyorsa `tdigest.scm` dosyasının başındaki
`+inf` ve `-inf` tanımlarını ayarlamanız gerekebilir.

---

## Standard ML

**Gereksinimler:** MLton (derleme için) veya SML/NJ (etkileşimli kullanım için)

**MLton ile:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**SML/NJ ile:**

```bash
cd sml/
sml demo.sml
```

MLB dosyası (`demo.mlb`), MLton'un derleme sistemi için basis kütüphanesini ve
kaynak dosyalarını listeler.

---

## Prolog

**Gereksinimler:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

Demo, `tdigest` modülünü yükler ve `:- initialization(main, main).`
direktifi aracılığıyla otomatik olarak çalışır.

Etkileşimli kullanım:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**Gereksinimler:** Mercury derleyicisi (`mmc`)

**Saf fonksiyonel sürüm** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Değiştirilebilir sürüm** (benzersizlik tipleriyle 2-3-4 ağacı):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Mercury derleme sistemi bağımlılıkları otomatik olarak derler
(`tdigest.m`, `fingertree.m`, `measured_tree234.m` vb.).

---

## C

**Gereksinimler:** GCC veya Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**Gereksinimler:** G++ veya Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**Gereksinimler:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**Gereksinimler:** Cargo ve Rust araç zinciri

```bash
cd rust/
cargo run --release
```

---

## Java

**Gereksinimler:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**Gereksinimler:** Kotlin derleyicisi

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**Gereksinimler:** Python 3 (harici bağımlılık yok)

```bash
cd python/
python3 demo.py
```

---

## Julia

**Gereksinimler:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**Gereksinimler:** ocamlfind ile OCaml derleyicisi

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**Gereksinimler:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**Gereksinimler:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**Gereksinimler:** GFortran veya başka bir Fortran 2003+ derleyicisi

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**Gereksinimler:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**Gereksinimler:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**Gereksinimler:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**Gereksinimler:** Zig derleyicisi

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**Gereksinimler:** Nim derleyicisi

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**Gereksinimler:** DMD veya LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**Gereksinimler:** .NET SDK veya Mono

**.NET SDK ile:**

```bash
cd csharp/
dotnet run
```

**Mono ile:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**Gereksinimler:** Swift derleyicisi

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
