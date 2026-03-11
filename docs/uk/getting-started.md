# Початок роботи

Кожна реалізація окремою мовою є самодостатньою і знаходиться у власному каталозі.
Міжмовних залежностей немає.

---

## Haskell

**Передумови:** GHC, пакети `fingertree` та `vector`

**Автономно (без засобу збірки):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**Як пакет Cabal (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Пакет Cabal надає два бібліотечних модулі:
`Data.Sketch.TDigest` (чистий, на основі finger tree) та
`Data.Sketch.TDigest.Mutable` (змінюваний, ST-монада з векторами).

**Використання у власному коді:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**Необхідно:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

Файл `tdigest.rb` містить як бібліотеку, так і демо у блоці
`if __FILE__ == $PROGRAM_NAME`. Для використання як бібліотеки:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**Необхідно:** GNAT (компілятор GCC Ada)

```bash
cd ada/
gnatmake demo.adb
./demo
```

Пакет розділений на `tdigest.ads` (специфікація), `tdigest.adb` (тіло)
та узагальнений пакет 2-3-4 дерева `tree234.ads`/`tree234.adb`.
Для використання у власному проєкті додайте `with TDigest;` у вихідний код і скомпілюйте всі файли разом.

---

## Common Lisp

**Необхідно:** SBCL або будь-яка реалізація ANSI Common Lisp

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Для інтерактивного використання:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**Необхідно:** CHICKEN Scheme (`csi`) або будь-яка реалізація R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Або з Guile:

```bash
guile demo.scm
```

Примітка: використовуються літерали `+inf.0` та `-inf.0` для нескінченності. Якщо ваша
реалізація Scheme використовує інші константи, можливо, потрібно буде змінити
визначення `+inf` та `-inf` на початку файлу `tdigest.scm`.

---

## Standard ML

**Необхідно:** MLton (для компіляції) або SML/NJ (для інтерактивного використання)

**З MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**З SML/NJ:**

```bash
cd sml/
sml demo.sml
```

Файл MLB (`demo.mlb`) містить перелік бібліотеки basis та вихідних файлів для
системи збірки MLton.

---

## Prolog

**Необхідно:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

Демо завантажує модуль `tdigest` і запускається автоматично через
директиву `:- initialization(main, main).`.

Для інтерактивного використання:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**Необхідно:** компілятор Mercury (`mmc`)

**Чисто функціональна версія** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Мутабельна версія** (2-3-4 дерево з типами унікальності):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Система збірки Mercury автоматично скомпілює залежності
(`tdigest.m`, `fingertree.m`, `measured_tree234.m` тощо).

---

## C

**Необхідно:** GCC або Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**Необхідно:** G++ або Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**Необхідно:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**Необхідно:** Cargo та набір інструментів Rust

```bash
cd rust/
cargo run --release
```

---

## Java

**Необхідно:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**Необхідно:** компілятор Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**Необхідно:** Python 3 (без зовнішніх залежностей)

```bash
cd python/
python3 demo.py
```

---

## Julia

**Необхідно:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**Необхідно:** компілятор OCaml з ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**Необхідно:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**Необхідно:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**Необхідно:** GFortran або інший компілятор Fortran 2003+

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**Необхідно:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**Необхідно:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**Необхідно:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**Необхідно:** компілятор Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**Необхідно:** компілятор Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**Необхідно:** DMD або LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**Необхідно:** .NET SDK або Mono

**З .NET SDK:**

```bash
cd csharp/
dotnet run
```

**З Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**Необхідно:** компілятор Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
