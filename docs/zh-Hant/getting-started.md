# 快速入門

每個語言實作都獨立包含在各自的目錄中。
語言之間沒有跨語言相依性。

---

## Haskell

**前提條件:** GHC、`fingertree` 和 `vector` 套件

**獨立運行（無需建構工具）:**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**作為 Cabal 套件 (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Cabal 套件提供兩個程式庫模組:
`Data.Sketch.TDigest`（純函式，基於指樹）和
`Data.Sketch.TDigest.Mutable`（可變，使用向量的 ST 單子）。

**在自己的程式碼中使用:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**前提條件:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

`tdigest.rb` 檔案同時包含函式庫和示範程式碼（在 `if __FILE__ == $PROGRAM_NAME` 區塊中）。作為函式庫使用時:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**前提條件:** GNAT（GCC Ada 編譯器）

```bash
cd ada/
gnatmake demo.adb
./demo
```

套件分為 `tdigest.ads`（規格）、`tdigest.adb`（主體）和通用的 `tree234.ads`/`tree234.adb` 2-3-4 樹套件。在自己的專案中使用時，在原始碼中撰寫 `with TDigest;` 並將所有檔案一起編譯。

---

## Common Lisp

**前提條件:** SBCL 或任何 ANSI Common Lisp 實作

```bash
cd common-lisp/
sbcl --script demo.lisp
```

互動式使用:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**前提條件:** CHICKEN Scheme (`csi`) 或任何 R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

或使用 Guile:

```bash
guile demo.scm
```

注意: 使用 `+inf.0` 和 `-inf.0` 字面值表示無窮大。如果您的 Scheme 實作使用不同的常數，可能需要調整 `tdigest.scm` 頂部的 `+inf` 和 `-inf` 定義。

---

## Standard ML

**前提條件:** MLton（編譯用）或 SML/NJ（互動式使用）

**使用 MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**使用 SML/NJ:**

```bash
cd sml/
sml demo.sml
```

MLB 檔案（`demo.mlb`）列出了 MLton 建置系統所需的 basis 函式庫和原始碼檔案。

---

## Prolog

**前提條件:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

示範程式載入 `tdigest` 模組，並透過 `:- initialization(main, main).` 指令自動執行。

互動式使用:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**前提條件:** Mercury 編譯器 (`mmc`)

**純函數式版本**（指樹）:

```bash
cd mercury/
mmc --make demo
./demo
```

**可變版本**（使用唯一性型別的 2-3-4 樹）:

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Mercury 建置系統將自動編譯相依項（`tdigest.m`、`fingertree.m`、`measured_tree234.m` 等）。

---

## C

**前提條件:** GCC 或 Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**前提條件:** G++ 或 Clang++（C++17）

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**前提條件:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**前提條件:** Cargo 和 Rust 工具鏈

```bash
cd rust/
cargo run --release
```

---

## Java

**前提條件:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**前提條件:** Kotlin 編譯器

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**前提條件:** Python 3（無外部相依性）

```bash
cd python/
python3 demo.py
```

---

## Julia

**前提條件:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**前提條件:** OCaml 編譯器和 ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**前提條件:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**前提條件:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**前提條件:** GFortran 或其他 Fortran 2003 以上編譯器

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**前提條件:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**前提條件:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**前提條件:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**前提條件:** Zig 編譯器

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**前提條件:** Nim 編譯器

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**前提條件:** DMD 或 LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**前提條件:** .NET SDK 或 Mono

**使用 .NET SDK:**

```bash
cd csharp/
dotnet run
```

**使用 Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**前提條件:** Swift 編譯器

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
