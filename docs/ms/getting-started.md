# Mula Pantas

Projek ini mengandungi pelaksanaan t-digest dalam 28 bahasa pengaturcaraan. Setiap pelaksanaan adalah serba lengkap dalam direktorinya sendiri. Tiada kebergantungan antara bahasa. Ikuti arahan di bawah untuk membina dan menjalankan setiap pelaksanaan.

## Klon Repositori

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## Membina dan Menjalankan Setiap Bahasa

### Haskell

**Prasyarat:** GHC, pakej `fingertree` dan `vector`

**Bersendirian (tanpa alat bina):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**Sebagai pakej Cabal (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Pakej Cabal mendedahkan dua modul pustaka:
`Data.Sketch.TDigest` (tulen, berasaskan finger tree) dan
`Data.Sketch.TDigest.Mutable` (boleh ubah, ST monad dengan vektor).

**Penggunaan dalam kod sendiri:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

**Prasyarat:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

Fail `tdigest.rb` mengandungi pustaka dan demo dalam blok `if __FILE__ == $PROGRAM_NAME`. Untuk menggunakannya sebagai pustaka:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

**Prasyarat:** GNAT (pengkompil Ada daripada GNU)

```bash
cd ada/
gnatmake demo.adb
./demo
```

---

### Common Lisp

**Prasyarat:** SBCL, atau mana-mana pelaksanaan ANSI Common Lisp

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Untuk penggunaan interaktif:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

**Prasyarat:** CHICKEN Scheme (`csi`), atau mana-mana Scheme R5RS/R7RS

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Atau dengan Guile:

```bash
guile demo.scm
```

---

### Standard ML

**Prasyarat:** MLton (untuk kompilasi) atau SML/NJ (untuk penggunaan interaktif)

**Dengan MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**Dengan SML/NJ:**

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

Untuk penggunaan interaktif:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

**Prasyarat:** Pengkompil Mercury (`mmc`)

**Versi fungsian tulen** (pokok jari):

```bash
cd mercury/
mmc --make demo
./demo
```

**Versi boleh ubah** (pokok 2-3-4 dengan jenis keunikan):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

---

### C

**Prasyarat:** GCC atau Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

**Prasyarat:** G++ atau Clang++ (C++17)

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

**Prasyarat:** Cargo dan rantai alat Rust

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

**Prasyarat:** Pengkompil Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

**Prasyarat:** Python 3 (tiada kebergantungan luaran)

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

**Prasyarat:** Pengkompil OCaml dengan ocamlfind

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

**Prasyarat:** GFortran atau pengkompil Fortran 2003+ yang lain

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

**Prasyarat:** Pengkompil Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

**Prasyarat:** Pengkompil Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

**Prasyarat:** DMD atau LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

**Prasyarat:** .NET SDK atau Mono

**Dengan .NET SDK:**

```bash
cd csharp/
dotnet run
```

**Dengan Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

**Prasyarat:** Pengkompil Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

## Output Demo

Setiap demo melaksanakan langkah-langkah berikut:

1. Memulakan t-digest
2. Menambah data sampel
3. Mengira dan memaparkan pelbagai kuantil (median, p90, p99, dll.)
4. Memaparkan perbandingan antara nilai anggaran dan nilai teori
