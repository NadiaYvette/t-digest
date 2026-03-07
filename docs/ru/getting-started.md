# Начало работы

Каждая реализация на отдельном языке является самодостаточной и находится в своём собственном каталоге.
Межъязыковых зависимостей нет.

---

## Haskell

**Необходимо:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

Модуль `TDigest` использует только библиотеки `base` (проект Cabal или Stack не требуется).

**Использование в собственном коде:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**Необходимо:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

Файл `tdigest.rb` содержит как библиотеку, так и демо в блоке
`if __FILE__ == $PROGRAM_NAME`. Для использования в качестве библиотеки:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**Необходимо:** GNAT (компилятор GCC Ada)

```bash
cd ada/
gnatmake demo.adb
./demo
```

Пакет разделён на `tdigest.ads` (спецификация), `tdigest.adb` (тело)
и обобщённый пакет 2-3-4 дерева `tree234.ads`/`tree234.adb`.
Для использования в собственном проекте добавьте `with TDigest;` в исходный код и скомпилируйте все файлы вместе.

---

## Common Lisp

**Необходимо:** SBCL или любая реализация ANSI Common Lisp

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Для интерактивного использования:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**Необходимо:** CHICKEN Scheme (`csi`) или любая реализация R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Или с Guile:

```bash
guile demo.scm
```

Примечание: используются литералы `+inf.0` и `-inf.0` для бесконечности. Если ваша
реализация Scheme использует другие константы, возможно, потребуется изменить
определения `+inf` и `-inf` в начале файла `tdigest.scm`.

---

## Standard ML

**Необходимо:** MLton (для компиляции) или SML/NJ (для интерактивного использования)

**С MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**С SML/NJ:**

```bash
cd sml/
sml demo.sml
```

Файл MLB (`demo.mlb`) перечисляет библиотеку basis и исходные файлы для
системы сборки MLton.

---

## Prolog

**Необходимо:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

Демо загружает модуль `tdigest` и запускается автоматически через
директиву `:- initialization(main, main).`.

Для интерактивного использования:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**Необходимо:** компилятор Mercury (`mmc`)

**Чисто функциональная версия** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Мутабельная версия** (2-3-4 дерево с типами уникальности):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Система сборки Mercury автоматически скомпилирует зависимости
(`tdigest.m`, `fingertree.m`, `measured_tree234.m` и т.д.).

---

## C

**Необходимо:** GCC или Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**Необходимо:** G++ или Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**Необходимо:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**Необходимо:** Cargo и набор инструментов Rust

```bash
cd rust/
cargo run --release
```

---

## Java

**Необходимо:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**Необходимо:** компилятор Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**Необходимо:** Python 3 (без внешних зависимостей)

```bash
cd python/
python3 demo.py
```

---

## Julia

**Необходимо:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**Необходимо:** компилятор OCaml с ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**Необходимо:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**Необходимо:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**Необходимо:** GFortran или другой компилятор Fortran 2003+

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**Необходимо:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**Необходимо:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**Необходимо:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**Необходимо:** компилятор Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**Необходимо:** компилятор Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**Необходимо:** DMD или LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**Необходимо:** .NET SDK или Mono

**С .NET SDK:**

```bash
cd csharp/
dotnet run
```

**С Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**Необходимо:** компилятор Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
