# 快速入門

呢個專案包含 28 種程式語言嘅 t-digest 實作。跟住下面嘅說明嚟建置同執行各個實作。

## 複製儲存庫

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## 各語言嘅建置同執行

### Haskell

**先決條件:** GHC、`fingertree` 同 `vector` 套件

**獨立運行（唔使構建工具）:**

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
`Data.Sketch.TDigest`（純粹、基於指樹）同
`Data.Sketch.TDigest.Mutable`（可變、用向量嘅 ST 單子）。

**喺自己嘅代碼入面使用:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

**需要：** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

`tdigest.rb` 入面包含程式庫同示範程式。用嚟做程式庫：

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

**需要：** GNAT（GCC Ada 編譯器）

```bash
cd ada/
gnatmake demo.adb
./demo
```

套件包括 `tdigest.ads`（規格）、`tdigest.adb`（主體）、同泛型 `tree234.ads`/`tree234.adb` 2-3-4 樹套件。

---

### Common Lisp

**需要：** SBCL，或者其他 ANSI Common Lisp 實作

```bash
cd common-lisp/
sbcl --script demo.lisp
```

互動使用：

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

**需要：** CHICKEN Scheme (`csi`)，或者其他 R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

或者用 Guile：

```bash
guile demo.scm
```

注意：用咗 `+inf.0` 同 `-inf.0` 嚟表示無限大。如果你嘅 Scheme 實作用唔同嘅常數，你可能要改 `tdigest.scm` 入面嘅 `+inf` 同 `-inf` 定義。

---

### Standard ML

**需要：** MLton（編譯用）或者 SML/NJ（互動用）

**用 MLton：**

```bash
cd sml/
mlton demo.mlb
./demo
```

**用 SML/NJ：**

```bash
cd sml/
sml demo.sml
```

MLB 檔案（`demo.mlb`）列出基礎程式庫同原始碼檔案。

---

### Prolog

**需要：** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

示範程式載入 `tdigest` 模組，透過 `:- initialization(main, main).` 指示自動執行。

互動使用：

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

**需要：** Mercury 編譯器（`mmc`）

**純函數版本**（finger tree）：

```bash
cd mercury/
mmc --make demo
./demo
```

**可變版本**（2-3-4 樹，用唯一性類型）：

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Mercury 建置系統會自動編譯依賴項（`tdigest.m`、`fingertree.m`、`measured_tree234.m` 等等）。

---

### C

**需要：** GCC 或者 Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

**需要：** G++ 或者 Clang++（C++17）

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

**需要：** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

### Rust

**需要：** Cargo 同 Rust 工具鏈

```bash
cd rust/
cargo run --release
```

---

### Java

**需要：** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

**需要：** Kotlin 編譯器

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

**需要：** Python 3（冇外部相依性）

```bash
cd python/
python3 demo.py
```

---

### Julia

**需要：** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

### OCaml

**需要：** OCaml 編譯器同 ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

**需要：** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

**需要：** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

**需要：** GFortran 或者其他 Fortran 2003+ 編譯器

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

**需要：** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

**需要：** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

### R

**需要：** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

### Zig

**需要：** Zig 編譯器

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

**需要：** Nim 編譯器

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

**需要：** DMD 或者 LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

**需要：** .NET SDK 或者 Mono

**用 .NET SDK：**

```bash
cd csharp/
dotnet run
```

**用 Mono：**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

**需要：** Swift 編譯器

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

## 示範輸出

每個示範程式會做以下嘢：

1. 初始化 t-digest
2. 加入樣本資料
3. 計算同顯示各種分位數（中位數、p90、p99 等等）
4. 顯示估計值同理論值嘅比較結果
