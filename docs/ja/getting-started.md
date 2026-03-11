# クイックスタート

各言語の実装はそれぞれのディレクトリに独立しています。
言語間の依存関係はありません。

---

## Haskell

**前提条件:** GHC、`fingertree` および `vector` パッケージ

**スタンドアロン（ビルドツールなし）:**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**Cabal パッケージとして (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Cabal パッケージは2つのライブラリモジュールを公開します:
`Data.Sketch.TDigest`（純粋、フィンガーツリーベース）および
`Data.Sketch.TDigest.Mutable`（ミュータブル、ベクターを使用した ST モナド）。

**自身のコードでの使用:**

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

`tdigest.rb` にはライブラリとデモの両方が含まれています（`if __FILE__ == $PROGRAM_NAME` ブロック内）。ライブラリとして使用する場合:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**前提条件:** GNAT（GCC Ada コンパイラ）

```bash
cd ada/
gnatmake demo.adb
./demo
```

パッケージは `tdigest.ads`（仕様）、`tdigest.adb`（本体）、および汎用の `tree234.ads`/`tree234.adb` 2-3-4 木パッケージに分かれています。自身のプロジェクトで使用するには、ソースに `with TDigest;` を記述し、すべてのファイルを一緒にコンパイルしてください。

---

## Common Lisp

**前提条件:** SBCL、または任意の ANSI Common Lisp 処理系

```bash
cd common-lisp/
sbcl --script demo.lisp
```

対話的に使用する場合:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**前提条件:** CHICKEN Scheme (`csi`)、または任意の R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

または Guile を使用する場合:

```bash
guile demo.scm
```

注意: 無限大には `+inf.0` および `-inf.0` リテラルが使用されています。お使いの Scheme 処理系が異なる定数を使用する場合は、`tdigest.scm` の先頭にある `+inf` と `-inf` の定義を調整する必要があるかもしれません。

---

## Standard ML

**前提条件:** MLton（コンパイル用）または SML/NJ（対話的使用）

**MLton の場合:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**SML/NJ の場合:**

```bash
cd sml/
sml demo.sml
```

MLB ファイル（`demo.mlb`）には、MLton のビルドシステム用に basis ライブラリとソースファイルがリストされています。

---

## Prolog

**前提条件:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

デモは `tdigest` モジュールをロードし、`:- initialization(main, main).` ディレクティブにより自動的に実行されます。

対話的に使用する場合:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**前提条件:** Mercury コンパイラ (`mmc`)

**純粋関数型バージョン**（フィンガーツリー）:

```bash
cd mercury/
mmc --make demo
./demo
```

**ミュータブルバージョン**（一意性型を使用した 2-3-4 木）:

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Mercury ビルドシステムが依存関係（`tdigest.m`、`fingertree.m`、`measured_tree234.m` など）を自動的にコンパイルします。

---

## C

**前提条件:** GCC または Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**前提条件:** G++ または Clang++（C++17）

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

**前提条件:** Cargo および Rust ツールチェーン

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

**前提条件:** Kotlin コンパイラ

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**前提条件:** Python 3（外部依存なし）

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

**前提条件:** OCaml コンパイラおよび ocamlfind

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

**前提条件:** GFortran またはその他の Fortran 2003 以降のコンパイラ

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

**前提条件:** Zig コンパイラ

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**前提条件:** Nim コンパイラ

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**前提条件:** DMD または LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**前提条件:** .NET SDK または Mono

**.NET SDK の場合:**

```bash
cd csharp/
dotnet run
```

**Mono の場合:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**前提条件:** Swift コンパイラ

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
