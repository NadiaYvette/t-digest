# 빠른 시작

각 언어 구현은 자체 디렉터리에 독립적으로 포함되어 있습니다.
언어 간 의존성은 없습니다.

---

## Haskell

**전제 조건:** GHC, `fingertree` 및 `vector` 패키지

**독립 실행 (빌드 도구 없이):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**Cabal 패키지로 (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Cabal 패키지는 두 개의 라이브러리 모듈을 제공합니다:
`Data.Sketch.TDigest` (순수, 핑거 트리 기반) 및
`Data.Sketch.TDigest.Mutable` (변경 가능, 벡터를 사용한 ST 모나드).

**자신의 코드에서 사용:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**전제 조건:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

`tdigest.rb` 파일에는 라이브러리와 데모가 모두 포함되어 있습니다 (`if __FILE__ == $PROGRAM_NAME` 블록 내). 라이브러리로 사용하려면:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**전제 조건:** GNAT (GCC Ada 컴파일러)

```bash
cd ada/
gnatmake demo.adb
./demo
```

패키지는 `tdigest.ads` (사양), `tdigest.adb` (본체), 그리고 제네릭 `tree234.ads`/`tree234.adb` 2-3-4 트리 패키지로 분리되어 있습니다. 자체 프로젝트에서 사용하려면 소스에 `with TDigest;`를 작성하고 모든 파일을 함께 컴파일하세요.

---

## Common Lisp

**전제 조건:** SBCL 또는 모든 ANSI Common Lisp 구현체

```bash
cd common-lisp/
sbcl --script demo.lisp
```

대화형으로 사용하려면:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**전제 조건:** CHICKEN Scheme (`csi`) 또는 모든 R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

또는 Guile을 사용하는 경우:

```bash
guile demo.scm
```

참고: 무한대를 위해 `+inf.0` 및 `-inf.0` 리터럴이 사용됩니다. 사용하는 Scheme 구현체가 다른 상수를 사용하는 경우, `tdigest.scm` 상단의 `+inf` 및 `-inf` 정의를 조정해야 할 수 있습니다.

---

## Standard ML

**전제 조건:** MLton (컴파일용) 또는 SML/NJ (대화형 사용)

**MLton 사용 시:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**SML/NJ 사용 시:**

```bash
cd sml/
sml demo.sml
```

MLB 파일 (`demo.mlb`)에는 MLton 빌드 시스템을 위한 basis 라이브러리와 소스 파일이 나열되어 있습니다.

---

## Prolog

**전제 조건:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

데모는 `tdigest` 모듈을 로드하고 `:- initialization(main, main).` 지시문을 통해 자동으로 실행됩니다.

대화형으로 사용하려면:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**전제 조건:** Mercury 컴파일러 (`mmc`)

**순수 함수형 버전** (핑거 트리):

```bash
cd mercury/
mmc --make demo
./demo
```

**가변 버전** (유일성 타입을 사용한 2-3-4 트리):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Mercury 빌드 시스템이 의존성 (`tdigest.m`, `fingertree.m`, `measured_tree234.m` 등)을 자동으로 컴파일합니다.

---

## C

**전제 조건:** GCC 또는 Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**전제 조건:** G++ 또는 Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**전제 조건:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**전제 조건:** Cargo 및 Rust 툴체인

```bash
cd rust/
cargo run --release
```

---

## Java

**전제 조건:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**전제 조건:** Kotlin 컴파일러

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**전제 조건:** Python 3 (외부 의존성 없음)

```bash
cd python/
python3 demo.py
```

---

## Julia

**전제 조건:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**전제 조건:** OCaml 컴파일러 및 ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**전제 조건:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**전제 조건:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**전제 조건:** GFortran 또는 기타 Fortran 2003 이상 컴파일러

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**전제 조건:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**전제 조건:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**전제 조건:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**전제 조건:** Zig 컴파일러

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**전제 조건:** Nim 컴파일러

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**전제 조건:** DMD 또는 LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**전제 조건:** .NET SDK 또는 Mono

**.NET SDK 사용 시:**

```bash
cd csharp/
dotnet run
```

**Mono 사용 시:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**전제 조건:** Swift 컴파일러

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
