# Pierwsze kroki

Każda implementacja w danym języku jest samodzielna i znajduje się we własnym katalogu.
Nie ma zależności między językami.

---

## Haskell

**Wymagania:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

Moduł `TDigest` używa wyłącznie bibliotek `base` (nie jest wymagany projekt Cabal ani Stack).

**Użycie we własnym kodzie:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**Wymagania:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

Plik `tdigest.rb` zawiera zarówno bibliotekę, jak i demo w bloku
`if __FILE__ == $PROGRAM_NAME`. Aby użyć jako biblioteki:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**Wymagania:** GNAT (kompilator GCC Ada)

```bash
cd ada/
gnatmake demo.adb
./demo
```

Pakiet jest podzielony na `tdigest.ads` (specyfikacja), `tdigest.adb` (ciało)
oraz generyczny pakiet drzewa 2-3-4 `tree234.ads`/`tree234.adb`.
Aby użyć we własnym projekcie, dodaj `with TDigest;` w kodzie źródłowym i skompiluj wszystkie pliki razem.

---

## Common Lisp

**Wymagania:** SBCL lub dowolna implementacja ANSI Common Lisp

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Użycie interaktywne:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**Wymagania:** CHICKEN Scheme (`csi`) lub dowolna implementacja R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Lub z Guile:

```bash
guile demo.scm
```

Uwaga: używane są literały `+inf.0` i `-inf.0` dla nieskończoności. Jeśli Twoja
implementacja Scheme używa innych stałych, może być konieczna zmiana
definicji `+inf` i `-inf` na początku pliku `tdigest.scm`.

---

## Standard ML

**Wymagania:** MLton (do kompilacji) lub SML/NJ (do użytku interaktywnego)

**Z MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**Z SML/NJ:**

```bash
cd sml/
sml demo.sml
```

Plik MLB (`demo.mlb`) zawiera listę biblioteki basis i plików źródłowych dla
systemu budowania MLton.

---

## Prolog

**Wymagania:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

Demo ładuje moduł `tdigest` i uruchamia się automatycznie za pomocą
dyrektywy `:- initialization(main, main).`.

Użycie interaktywne:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**Wymagania:** kompilator Mercury (`mmc`)

**Wersja czysto funkcyjna** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Wersja mutowalna** (drzewo 2-3-4 z typami unikalności):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

System budowania Mercury automatycznie skompiluje zależności
(`tdigest.m`, `fingertree.m`, `measured_tree234.m` itd.).

---

## C

**Wymagania:** GCC lub Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**Wymagania:** G++ lub Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**Wymagania:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**Wymagania:** Cargo i zestaw narzędzi Rust

```bash
cd rust/
cargo run --release
```

---

## Java

**Wymagania:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**Wymagania:** kompilator Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**Wymagania:** Python 3 (bez zewnętrznych zależności)

```bash
cd python/
python3 demo.py
```

---

## Julia

**Wymagania:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**Wymagania:** kompilator OCaml z ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**Wymagania:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**Wymagania:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**Wymagania:** GFortran lub inny kompilator Fortran 2003+

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**Wymagania:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**Wymagania:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**Wymagania:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**Wymagania:** kompilator Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**Wymagania:** kompilator Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**Wymagania:** DMD lub LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**Wymagania:** .NET SDK lub Mono

**Z .NET SDK:**

```bash
cd csharp/
dotnet run
```

**Z Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**Wymagania:** kompilator Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
