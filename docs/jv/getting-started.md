# Wiwit Cepet

Proyek iki ngemot implementasi t-digest ing 28 basa pemrograman. Saben implementasi mandiri ing direktori dhewe-dhewe. Ora ana dependensi antar basa. Tindakna pandhuan ing ngisor iki kanggo mbangun lan mbukak saben implementasi.

## Kloning Repositori

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## Mbangun lan Mbukak Saben Basa

### Haskell

**Prasyarat:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

Modul `TDigest` mung nggunakake pustaka `base` (ora perlu proyek Cabal utawa Stack).

**Panganggo ing kode sampeyan dhewe:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

**Prasyarat:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

File `tdigest.rb` ngemot pustaka lan demo ing blok `if __FILE__ == $PROGRAM_NAME`. Kanggo nggunakake minangka pustaka:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

**Prasyarat:** GNAT (kompiler Ada saka GNU)

```bash
cd ada/
gnatmake demo.adb
./demo
```

---

### Common Lisp

**Prasyarat:** SBCL, utawa implementasi ANSI Common Lisp apa wae

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Kanggo panganggo interaktif:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

**Prasyarat:** CHICKEN Scheme (`csi`), utawa Scheme R5RS/R7RS apa wae

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Utawa nganggo Guile:

```bash
guile demo.scm
```

---

### Standard ML

**Prasyarat:** MLton (kanggo kompilasi) utawa SML/NJ (kanggo panganggo interaktif)

**Nganggo MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**Nganggo SML/NJ:**

```bash
cd sml/
sml demo.sml
```

---

### Prolog

**Prasyarat:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

Kanggo panganggo interaktif:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

**Prasyarat:** Kompiler Mercury (`mmc`)

**Versi fungsional murni** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Versi bisa diowahi** (2-3-4 tree karo tipe keunikan):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

---

### C

**Prasyarat:** GCC utawa Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

**Prasyarat:** G++ utawa Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

**Prasyarat:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

### Rust

**Prasyarat:** Cargo lan toolchain Rust

```bash
cd rust/
cargo run --release
```

---

### Java

**Prasyarat:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

**Prasyarat:** Kompiler Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

**Prasyarat:** Python 3 (ora ana dependensi eksternal)

```bash
cd python/
python3 demo.py
```

---

### Julia

**Prasyarat:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

### OCaml

**Prasyarat:** Kompiler OCaml karo ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

**Prasyarat:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

**Prasyarat:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

**Prasyarat:** GFortran utawa kompiler Fortran 2003+ liyane

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

**Prasyarat:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

**Prasyarat:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

### R

**Prasyarat:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

### Zig

**Prasyarat:** Kompiler Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

**Prasyarat:** Kompiler Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

**Prasyarat:** DMD utawa LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

**Prasyarat:** .NET SDK utawa Mono

**Nganggo .NET SDK:**

```bash
cd csharp/
dotnet run
```

**Nganggo Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

**Prasyarat:** Kompiler Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

## Output Demo

Saben demo nglakokake langkah-langkah iki:

1. Inisialisasi t-digest
2. Nambahake data sampel
3. Ngitung lan nampilake macem-macem kuantil (median, p90, p99, lsp.)
4. Nampilake perbandingan antara nilai estimasi lan nilai teoritis
