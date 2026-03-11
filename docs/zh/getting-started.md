# 快速入门

每个语言实现都独立包含在各自的目录中。
语言之间没有跨语言依赖关系。

---

## Haskell

**前提条件:** GHC、`fingertree` 和 `vector` 包

**独立运行（无需构建工具）:**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**作为 Cabal 包 (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Cabal 包提供两个库模块:
`Data.Sketch.TDigest`（纯函数式，基于指树）和
`Data.Sketch.TDigest.Mutable`（可变，使用向量的 ST 单子）。

**在自己的代码中使用:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**前提条件:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

`tdigest.rb` 文件同时包含库和演示代码（在 `if __FILE__ == $PROGRAM_NAME` 块中）。作为库使用时:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**前提条件:** GNAT（GCC Ada 编译器）

```bash
cd ada/
gnatmake demo.adb
./demo
```

包分为 `tdigest.ads`（规范）、`tdigest.adb`（主体）和通用的 `tree234.ads`/`tree234.adb` 2-3-4 树包。在自己的项目中使用时，在源码中编写 `with TDigest;` 并将所有文件一起编译。

---

## Common Lisp

**前提条件:** SBCL 或任何 ANSI Common Lisp 实现

```bash
cd common-lisp/
sbcl --script demo.lisp
```

交互式使用:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**前提条件:** CHICKEN Scheme (`csi`) 或任何 R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

或使用 Guile:

```bash
guile demo.scm
```

注意: 使用 `+inf.0` 和 `-inf.0` 字面量表示无穷大。如果您的 Scheme 实现使用不同的常量，可能需要调整 `tdigest.scm` 顶部的 `+inf` 和 `-inf` 定义。

---

## Standard ML

**前提条件:** MLton（编译用）或 SML/NJ（交互式使用）

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

MLB 文件（`demo.mlb`）列出了 MLton 构建系统所需的 basis 库和源文件。

---

## Prolog

**前提条件:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

演示程序加载 `tdigest` 模块，并通过 `:- initialization(main, main).` 指令自动运行。

交互式使用:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**前提条件:** Mercury 编译器 (`mmc`)

**纯函数式版本**（指树）:

```bash
cd mercury/
mmc --make demo
./demo
```

**可变版本**（使用唯一性类型的 2-3-4 树）:

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Mercury 构建系统将自动编译依赖项（`tdigest.m`、`fingertree.m`、`measured_tree234.m` 等）。

---

## C

**前提条件:** GCC 或 Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**前提条件:** G++ 或 Clang++（C++17）

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**前提条件:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**前提条件:** Cargo 和 Rust 工具链

```bash
cd rust/
cargo run --release
```

---

## Java

**前提条件:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**前提条件:** Kotlin 编译器

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**前提条件:** Python 3（无外部依赖）

```bash
cd python/
python3 demo.py
```

---

## Julia

**前提条件:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**前提条件:** OCaml 编译器和 ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**前提条件:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**前提条件:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**前提条件:** GFortran 或其他 Fortran 2003 以上编译器

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**前提条件:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**前提条件:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**前提条件:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**前提条件:** Zig 编译器

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**前提条件:** Nim 编译器

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**前提条件:** DMD 或 LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**前提条件:** .NET SDK 或 Mono

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

**前提条件:** Swift 编译器

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
